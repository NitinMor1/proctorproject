# ProctorAI - Professional Remote Proctoring System

ProctorAI is a sophisticated AI-based remote proctoring solution designed to maintain examination integrity. It combines biometric identity verification with real-time behavior monitoring to provide a secure testing environment.

## 🚀 Key Features

### 👤 Identity & Auth
- **Face Authentication**: Secure biometric login and registration using custom Face Recognition SDK.
- **Role-Based Access**: Separate flows for Students and Administrators.

### 🛡️ AI Proctoring (Real-time)
- **Continuous Monitoring**: Live camera feed during exams.
- **Biometric Loops**: Verify student identity continuously throughout the session.
- **Violation Logging**: Automatically logs suspicious activities (looking away, multiple faces, tab switching).
- **Integrity Scoring**: Dynamic scoring engine that adjusts based on behavior.

### 📊 Administrative Dashboard
- **Exam Management**: Create, update, and manage exams and questions.
- **Student Monitoring**: Review student registration and biometric data.
- **Session Reports**: Detailed integrity reports with violation logs and final scores.

---

## 🛠️ Tech Stack

- **Frontend**: Flutter (Web)
- **State Management**: Flutter Riverpod
- **Backend**: Node.js & Express
- **Database**: MongoDB (Atlas)
- **Authentication**: JWT & Biometrics
- **Hosting**: 
  - **Backend**: Render (Web Service)
  - **Frontend**: Firebase Hosting

---

## 📂 Project Structure

```text
proctorproject/
├── backend/            # Express API
│   ├── src/
│   │   ├── models/     # Mongoose Schemas (User, Exam, Session, etc.)
│   │   ├── routes/     # API Endpoints
│   │   └── config/     # DB & App config
│   └── index.js        # Entry point
└── frontend/           # Flutter Web Application
    ├── lib/
    │   ├── core/       # API services, themes, and global providers
    │   └── features/   # Feature-based architecture (Admin, Auth, Exam)
    └── web/            # Web-specific configurations (Firebase, Vercel)
```

---

## ⚙️ Installation & Setup

### Prerequisites
- Flutter SDK (v3.10+)
- Node.js (v18+)
- MongoDB Atlas Account

### 1. Backend Setup
1. Navigate to directory: `cd backend`
2. Install dependencies: `npm install`
3. Create a `.env` file:
   ```env
   PORT=5000
   MONGODB_URI=your_mongodb_atlas_uri
   JWT_SECRET=your_jwt_secret_key
   ```
4. Start development server: `npm start`

### 2. Frontend Setup
1. Navigate to directory: `cd frontend`
2. Install dependencies: `flutter pub get`
3. Build for web (Production):
   ```bash
   flutter build web --release --dart-define=BASE_URL=http://localhost:5000/api
   ```
4. Run locally: `flutter run -d chrome`

---

## 🌐 Deployment Instructions

### Backend (Render)
1. Push `backend` directory to a private GitHub repo.
2. Create a **Web Service** on [Render.com](https://render.com).
3. Set environment variables (`MONGODB_URI`, `JWT_SECRET`).
4. Note your live URL (e.g., `https://proctor-backend.onrender.com`).

### Frontend (Firebase)
1. Initialize Firebase: `firebase init hosting`
2. Build with your live backend URL:
   ```bash
   flutter build web --release --dart-define=BASE_URL=https://your-backend.onrender.com/api
   ```
3. Deploy: `firebase deploy`

---

## 📄 License
Project created for educational and professional integrity assessment purposes.
