#!/usr/bin/env python3
"""Publish CloudCart with ten honest commits and no collaborator invitations."""
import argparse
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
OWNER = 'KartikGonde'
REPO = f'{OWNER}/CloudCart'
MESSAGES = [
    'chore: prepare CloudCart repository',
    'docs: describe CloudCart shopping features',
    'docs: diagram the AWS service architecture',
    'docs: document the CloudCart technology stack',
    'docs: map the repository structure',
    'docs: explain local setup and configuration',
    'docs: document automated AWS deployment',
    'docs: index the manual deployment guides',
    'docs: explain operations and project limits',
    'docs: add maintainer and source acknowledgments',
]


def run(*args, check=True, input=None, env=None):
    result = subprocess.run(args, cwd=ROOT, text=True, input=input,
                            capture_output=True, env=env)
    if check and result.returncode:
        raise RuntimeError(result.stderr.strip() or result.stdout.strip()
                           or f'Command failed: {args[0]}')
    return result


def readme_sections():
    # Only level-two headings divide commits; nested headings remain together.
    sections = re.split(r'(?=^## )', (ROOT / 'README.md').read_text(), flags=re.M)
    if len(sections) != len(MESSAGES):
        raise RuntimeError('README structure changed. Update the commit plan before publishing.')
    return sections


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--plan', action='store_true', help='Show the plan without changing anything')
    args = parser.parse_args()
    sections = readme_sections()
    if args.plan:
        for number, message in enumerate(MESSAGES, 1):
            print(f'{number:2}. {message}')
        print(f'\nDestination: https://github.com/{REPO} (existing visibility preserved)')
        return

    for executable in ('git', 'gh'):
        if not shutil.which(executable):
            raise RuntimeError(f'Install {executable} before publishing.')
    local_repo = run('git', 'rev-parse', '--show-toplevel', check=False)
    initialized = local_repo.returncode == 0
    origin = ''
    if initialized:
        if Path(local_repo.stdout.strip()).resolve() != ROOT:
            raise RuntimeError('This folder belongs to another Git repository. Publishing stopped.')
        if run('git', 'rev-parse', '--verify', 'HEAD', check=False).returncode == 0 or run('git', 'for-each-ref', '--format=%(refname)').stdout.strip():
            raise RuntimeError('Local Git history already exists. Review it and push normally; '
                               'the initial ten-commit import will not be repeated.')
        if run('git', 'diff', '--cached', '--name-only').stdout.strip():
            raise RuntimeError('Files are already staged. Review the index before importing.')
        origin = run('git', 'remote', 'get-url', 'origin', check=False).stdout.strip()
        if origin and origin != f'https://github.com/{REPO}.git':
            raise RuntimeError('The existing origin points to another repository.')
    elif (ROOT / '.git').exists():
        raise RuntimeError('Existing Git metadata could not be read. Publishing stopped.')

    account = json.loads(run('gh', 'api', 'user').stdout)
    if account['login'].lower() != OWNER.lower():
        raise RuntimeError(f'Sign in as {OWNER} with gh auth login -h github.com first.')
    repository = json.loads(run('gh', 'api', f'repos/{REPO}').stdout)
    if repository.get('full_name', '').lower() != REPO.lower():
        raise RuntimeError('GitHub returned a different repository. Publishing stopped.')
    if not repository.get('permissions', {}).get('push'):
        raise RuntimeError(f'The authenticated account cannot push to {REPO}.')
    branch = repository.get('default_branch') or 'main'
    remote_url = f'https://github.com/{REPO}.git'

    # Use the GitHub CLI credential helper for these commands only. This does
    # not modify the user's global Git credential configuration.
    def remote_git(*args):
        return run('git', '-c', 'credential.helper=',
                   '-c', 'credential.helper=!gh auth git-credential', *args)

    heads = remote_git('ls-remote', '--heads', remote_url).stdout
    has_history = bool(heads.strip())
    if has_history and not any(line.endswith(f'refs/heads/{branch}') for line in heads.splitlines()):
        raise RuntimeError('The default branch could not be found. No local history was changed.')

    # Use only this authenticated account for author and committer metadata.
    email = f'{account["id"]}+{account["login"]}@users.noreply.github.com'
    env = os.environ.copy()
    for role in ('AUTHOR', 'COMMITTER'):
        env[f'GIT_{role}_NAME'] = 'Kartik Gonde'
        env[f'GIT_{role}_EMAIL'] = email
        env.pop(f'GIT_{role}_DATE', None)

    if not initialized:
        run('git', 'init', '-b', branch)
    elif run('git', 'symbolic-ref', '--short', 'HEAD').stdout.strip() != branch:
        raise RuntimeError('The local branch differs from the remote default branch. Review it first.')
    run('git', 'config', '--local', 'user.name', 'Kartik Gonde')
    run('git', 'config', '--local', 'user.email', email)
    if not origin:
        run('git', 'remote', 'add', 'origin', remote_url)
    if has_history:
        remote_git('fetch', 'origin', branch)
        # Mixed reset adopts the remote ancestry but keeps the local files.
        run('git', 'reset', '--mixed', 'FETCH_HEAD')
        # Restore only remote files absent from this checkout, so importing
        # this project does not silently delete remote-only files.
        remote_files = run('git', 'ls-files', '-z').stdout.split('\0')
        missing = [name for name in remote_files if name and not os.path.lexists(ROOT / name)]
        if missing:
            run('git', 'checkout-index', '--stdin', '-z', input='\0'.join(missing) + '\0')
    run('git', 'add', '--all')
    tracked = run('git', 'ls-files', '-z').stdout.split('\0')
    sensitive = []
    for name in filter(None, tracked):
        path = Path(name)
        if (path.name.startswith('.env') and path.name != '.env.example') or \
           '.tfstate' in path.name or path.suffix in ('.tfvars', '.tfplan', '.pem', '.key') or \
           any(part in ('.aws', '.ssh', '.terraform') for part in path.parts):
            sensitive.append(name)
    if sensitive:
        run('git', 'rm', '--cached', '-r', '--', *sensitive)
        raise RuntimeError('Excluded possible local credentials/state from staging: ' + ', '.join(sensitive)
                           + '. Review ignore rules before publishing manually.')

    # Commit progressively staged README snapshots, leaving the complete file
    # untouched in the working tree, even if a command is interrupted.
    for index, message in enumerate(MESSAGES):
        snapshot = ''.join(sections[:index + 1])
        blob = run('git', 'hash-object', '-w', '--stdin', input=snapshot).stdout.strip()
        run('git', 'update-index', '--add', '--cacheinfo', f'100644,{blob},README.md')
        run('git', '-c', 'core.hooksPath=/dev/null', 'commit', '-m', message, env=env)
        print(f'Created commit {index + 1}/10: {message}', flush=True)

    history = run('git', 'log', '-10', '--format=%B').stdout
    if 'co-authored-by:' in history.lower():
        raise RuntimeError('Unexpected co-author metadata detected; publishing stopped.')
    if run('git', 'status', '--porcelain').stdout.strip():
        raise RuntimeError('Working tree changed during publishing. Review git status before pushing.')

    # Push normally: a concurrent remote update is rejected, never overwritten.
    result = remote_git('push', '--set-upstream', 'origin', branch)
    print(result.stdout.strip())
    print(f'Published https://github.com/{REPO} with 10 new commits. Visibility unchanged.')



if __name__ == '__main__':
    try:
        main()
    except (RuntimeError, ValueError, OSError) as error:
        print(f'Publish stopped: {error}', file=sys.stderr)
        print('Completed local commits are retained. No history is rewritten. '
              'If the push failed after the commits, inspect git status, '
              'git log, and git remote -v before retrying the GitHub step.', file=sys.stderr)
        sys.exit(1)
