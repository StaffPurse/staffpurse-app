<div align="center">
  <!-- 🖼️ Banner/Logo Placeholder -->
  <img src="https://via.placeholder.com/800x200/1e1e2e/a6accd?text=StaffPurse+staffpurse-app" alt="" width="100%" />

  <h1>StaffPurse App</h1>
  <p><strong>Mobile app and backend anchoring job for StaffPurse spend management.</strong></p>

  <p>
    <img src="https://img.shields.io/github/actions/workflow/status/StaffPurse/staffpurse-app/edge-ci.yml?branch=main" alt="CI Status" />
    <img src="https://img.shields.io/badge/License-MIT-blue.svg" alt="License" />
  </p>

  <p>
    <a href="https://staffpurse.gitbook.io"><strong>Documentation</strong></a> ·
    <a href="https://t.me/+Gflo5jZStw1jMjE0"><strong>Community Telegram</strong></a>
  </p>
</div>

## 📖 Overview

A spend control platform for Nigeria's informal micro-businesses allowing instant virtual card issuance. This repository houses the main Flutter mobile application (powered by BMONI) as well as the backend Edge Functions that aggregate and anchor daily spend proofs to the Stellar blockchain.

## 🏗 Architecture

The **Flutter client** enforces self-custody via secure hardware-enclaves for EIP-191 signing. The backend uses **Supabase (PostgreSQL)** for off-chain record keeping, while **Deno Edge Functions** execute daily cron jobs to build Merkle trees and submit them to the Soroban RPC.

## 🚀 Quick Start

```bash
# 1. Start the Flutter Mobile App
flutter pub get
flutter run

# 2. Run the Backend Edge Functions locally
supabase start
supabase functions serve
```

## 🤝 Contributing

Please read our [Contributing Guidelines](CONTRIBUTING.md) and [Security Policy](SECURITY.md) before submitting pull requests. All PRs must pass the CI gates and follow our code quality standards.

## 👥 Maintainers

| Name | Contact | Role |
| :--- | :--- | :--- |
| Ademola | [Telegram](https://t.me/placeholder) | Core Maintainer |

## ✨ Contributors

<a href="https://github.com/StaffPurse/staffpurse-app/graphs/contributors">
  <img src="https://contrib.rocks/image?repo=StaffPurse/staffpurse-app" alt="Contributors" />
</a>
