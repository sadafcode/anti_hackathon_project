# KhidmatBot — Start Karne Ke Steps

## Prerequisites (Pehli Baar Setup)
- Node.js installed hona chahiye
- Flutter SDK installed hona chahiye
- Chrome browser hona chahiye
- `.env` file project root mein honi chahiye (Gemini API key ke saath)

---

## Terminal 1 — Backend Start Karo

```bash
cd D:\anti_hackathon_project
npm run dev
```

**Expected output:**
```
Server running on port 3000
```

**Agar error aaye:**
- `Cannot find module` → pehle `npm install` chala do
- `.env file not found` → check karo `.env` root mein hai ya nahi
- `Port 3000 already in use` → purana process kill karo:
  ```
  netstat -ano | findstr :3000
  taskkill /PID <PID_NUMBER> /F
  ```

---

## Terminal 2 — Flutter App Start Karo

```bash
cd D:\anti_hackathon_project\app
flutter run -d chrome
```

**Expected output:**
```
Launching lib/main.dart on Chrome...
```
Browser mein `localhost:XXXX` automatically khul jayega.

**Agar error aaye:**
- `flutter: command not found` → Flutter PATH mein add karo
- `pub get` error → pehle yeh chala do:
  ```
  flutter pub get
  ```
- Maps error (grey screen) → normal hai, map picker tab hi kaam karta hai jab API key valid ho

---

## Dono Saath Chala Ke Test Karo

1. Backend wala terminal pehle start karo — wait karo jab tak `Server running on port 3000` aaye
2. Phir Flutter wala terminal mein command chala do
3. Chrome mein app khulne ke baad chat screen par yeh type karo:

```
plumber chahiye kal G-13 mein
```

Agar backend connected hai to bot response dega.

---

## Band Karna

- Backend: `Ctrl + C` terminal mein
- Flutter: `q` press karo Flutter terminal mein ya Chrome band karo

---

## Quick Reference

| Cheez | Command | Directory |
|-------|---------|-----------|
| Backend start | `npm run dev` | `D:\anti_hackathon_project` |
| Flutter start | `flutter run -d chrome` | `D:\anti_hackathon_project\app` |
| Backend URL | `http://localhost:3000/api` | — |
| Stress tests | `npx ts-node backend/src/tests/stress_tests.ts` | `D:\anti_hackathon_project` |
