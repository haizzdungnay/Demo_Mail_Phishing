# Demo Web Only - Outlook Phishing with OTP

Web gia mao Outlook co xac minh 2 buoc (OTP) chi bang frontend va backend Node.js.

## Cau truc

```
demo web only/outlook-otp/
├── frontend/
│   └── index.html     # Trang login gia mao Outlook
├── backend/
│   ├── .env          # Cau hinh (khong commit)
│   ├── .env.example  # Mau cau hinh
│   ├── package.json
│   └── server.js     # API server (Express + Nodemailer)
└── .gitignore
```

## Cai dat

### 1. Cai dat dependencies

```bash
cd "demo web only/outlook-otp/backend"
npm install
```

### 2. Cau hinh email

```bash
cp .env.example .env
```

Chinh sua file `.env`:

```env
GMAIL_USER=your-email@gmail.com
GMAIL_PASS=your-app-password
PORT=3000
```

**Cach tao App Password Gmail:**
1. Vao https://myaccount.google.com
2. Chon **Bao mat** > **Xac minh 2 buoc** (bat bat buoc)
3. Chon **App passwords**
4. Tao app password moi (chon "Other" va dat ten "PhishLab")
5. Copy password 16 ky tu vao `.env`

### 3. Chay server

```bash
npm start
```

Server chay tai `http://localhost:3000`

### 4. Mo trang login

Mo file `frontend/index.html` trong trinh duyet.

Hoac su dung web server:

```bash
cd frontend
npx serve .
```

## Luu y bao mat

- Chi su dung trong mang noi bo, khong public
- Khong luu mat khau vao database, chi ghi log cuc bo
- Xoa `.env` va log sau khi su dung
- Khong su dung tai khoan Gmail chinh

## Huong dan su dung

1. Nhap email bat ky
2. Nhap mat khau bat ky (se duoc ghi log)
3. Ma OTP se duoc gui toi email da nhap (backend gui qua Gmail SMTP)
4. Nhap ma OTP de hoan tat

## Khac phuc loi thuong gap

### "Gửi email thất bại"

- Kiem tra App Password dung khong
- Kiem tra Gmail co bat 2-Step Verification khong
- Kiem tra tai khoan Gmail co bi khoa khong

### CORS error

- Backend da cau hinh `cors()` san
- Dam bao frontend goi dung URL backend

### OTP khong gui duoc

- Kiem tra `.env` co dung format khong
- Kiem tra Internet ket noi
