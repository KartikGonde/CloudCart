<div align="center">

# ☁️ CloudCart

### A cloud-native shopping experience, from storefront to infrastructure.

**Maintained by [Kartik Gonde](https://github.com/KartikGonde)**

![React](https://img.shields.io/badge/React-19-149ECA?style=flat-square&logo=react&logoColor=white)
![FastAPI](https://img.shields.io/badge/FastAPI-Python-009688?style=flat-square&logo=fastapi&logoColor=white)
![AWS](https://img.shields.io/badge/AWS-Cloud%20Infrastructure-232F3E?style=flat-square)
![Terraform](https://img.shields.io/badge/Terraform-Infrastructure%20as%20Code-844FBA?style=flat-square&logo=terraform&logoColor=white)
![Docker](https://img.shields.io/badge/Docker-Containers-2496ED?style=flat-square&logo=docker&logoColor=white)

[Features](#features) · [Architecture](#architecture) · [Getting started](#getting-started) · [Deployment](#automated-deployment) · [Maintainer](#maintainer-and-acknowledgments)

</div>

---

CloudCart is an e-commerce learning and portfolio project that connects a React storefront to four Python microservices on AWS. It brings product browsing, shopping carts, user profiles, and order processing together with container deployment, managed databases, and event-driven notifications.

This repository is maintained by **Kartik Gonde**. It includes both a Terraform deployment workflow and step-by-step AWS deployment guides.

## Features

| Capability | What the project includes |
| --- | --- |
| Product catalog | Product images, descriptions, prices, and stock information backed by DynamoDB |
| Shopping cart | Add and remove products, track quantities, and calculate totals |
| Accounts | Amazon Cognito sign-up/sign-in and a user profile service backed by PostgreSQL |
| Orders | Create orders from a cart and review order history |
| Order events | Publish to SNS, deliver events to an SQS queue, and optionally subscribe an email address |
| Cloud deployment | Build container images, provision infrastructure, and publish the frontend through `deploy.sh` |

The repository contains **four backend services**. Notifications use SNS and SQS infrastructure; a separate notification worker and payment gateway are not included.

