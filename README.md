# Budget Me (Agent Money)

Budget Me is a cross-platform (Android, iOS, Windows, macOS, Linux) budget tracking application built with Flutter. It helps users track their spending, income, and investments with ease, featuring AI-powered voice logging to simplify transaction entry.

## 🚀 Key Features

- **AI-Powered Voice Logging**: Record your transactions using voice. The app uses OpenAI's Whisper for transcription and GPT-4o-mini for parsing transactions from natural language.
- **Comprehensive Tracking**: Manage income, expenses, lend/borrow returns, and investments.
- **Dashboard & Analytics**: Visualize your financial health with interactive charts (fl_chart) and summaries.
- **Account Management**: Track multiple accounts (bank, cash, etc.) and their balances with automatic reconciliation.
- **Recurring Transactions**: Automate periodic income or expenses (rent, salary, etc.).
- **Subscriptions**: Keep track of OTT, bills, and memberships with due date notifications.
- **Cross-Platform**: Full support for Mobile (Android, iOS) and Desktop (Windows, macOS, Linux) with a responsive UI.
- **Privacy First**: Financial data is stored locally using SQLite. AI processing is proxied through a secure backend to keep API keys off-device.

## 🛠 Tech Stack

- **Frontend**: [Flutter](https://flutter.dev)
- **State Management**: [Riverpod](https://riverpod.dev)
- **Local Database**: [sqflite](https://pub.dev/packages/sqflite) (with FFI for desktop)
- **AI Integration**: OpenAI (Whisper & GPT-4o-mini)
- **Monetization**: Google Mobile Ads & [RevenueCat](https://www.revenuecat.com/)
- **Charts**: [fl_chart](https://pub.dev/packages/fl_chart)
- **Backend**: Cloudflare Workers (Node.js/TypeScript)

## 📂 Project Structure

- `lib/core`: Shared configurations, database helpers, theme, and global services.
- `lib/features`: Feature-based modular architecture:
    - `dashboard`: Main overview and navigation.
    - `transactions`: Manual and AI-powered transaction entry.
    - `analytics`: Detailed spending breakdowns and charts.
    - `accounts`: Wallet and bank account management.
    - `subscriptions`: Recurring bill tracking.
    - `recurring`: Automated transaction engine.
    - `onboarding`: User first-run experience.
- `backend/`: Cloudflare Workers proxy for OpenAI API.

## 🚦 Getting Started

### Prerequisites

- Flutter SDK (^3.9.0)
- Node.js & Wrangler (for backend deployment)

### Mobile/Desktop App

1. Clone the repository:
   ```bash
   git clone https://github.com/yourusername/budget-me.git
   ```
2. Install dependencies:
   ```bash
   flutter pub get
   ```
3. Environment Configuration:
   Create a `dart_defines.env` file in the root directory with the following variables:
   ```env
   PROXY_BASE_URL=your_backend_url
   PROXY_CLIENT_SECRET=your_secret
   RC_ANDROID_KEY=your_revenuecat_key
   RC_IOS_KEY=your_revenuecat_key
   ```
4. Run the application:
   - Using PowerShell: `.\run_debug.ps1`
   - Using Flutter CLI: `flutter run --dart-define-from-file=dart_defines.env`

### Backend (OpenAI Proxy)

The backend is located in the `backend/` directory.

1. Navigate to the folder:
   ```bash
   cd backend
   ```
2. Install dependencies:
   ```bash
   npm install
   ```
3. Deploy to Cloudflare Workers:
   ```bash
   npx wrangler deploy
   ```

## 📄 License

This project is private and not intended for redistribution. See `budget-me-privacy-policy.html` for details on data handling.
