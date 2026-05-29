require('dotenv').config();
const express = require('express');
const nodemailer = require('nodemailer');
const cors = require('cors');

const app = express();
app.use(cors());
app.use(express.json());

// Lưu OTP tạm (key = email, value = {otp, expiry})
const otpStore = {};

// Cấu hình Gmail transporter
const transporter = nodemailer.createTransport({
  service: 'gmail',
  auth: {
    user: process.env.GMAIL_USER,
    pass: process.env.GMAIL_PASS,
  },
});

// ===== API GỬI OTP =====
app.post('/send-otp', async (req, res) => {
  const { email } = req.body;
  if (!email) return res.status(400).json({ error: 'Thiếu email' });

  const otp = Math.floor(100000 + Math.random() * 900000).toString();
  otpStore[email] = { otp, expiry: Date.now() + 5 * 60 * 1000 };

  try {
    await transporter.sendMail({
      from: '"Microsoft Account" <' + process.env.GMAIL_USER + '>',
      to: email,
      subject: 'Mã xác minh Microsoft của bạn',
      html: `
        

          
Mã xác minh của bạn

          
Mã có hiệu lực trong 5 phút.


          
${otp}

          
Nếu bạn không yêu cầu, hãy bỏ qua email này.


        

      `,
    });
    res.json({ success: true });
  } catch (err) {
    res.status(500).json({ error: 'Gửi email thất bại: ' + err.message });
  }
});

// ===== API XÁC MINH OTP =====
app.post('/verify-otp', (req, res) => {
  const { email, otp } = req.body;
  const record = otpStore[email];
  if (!record) return res.status(400).json({ error: 'Không tìm thấy OTP' });
  if (Date.now() > record.expiry) {
    delete otpStore[email];
    return res.status(400).json({ error: 'OTP đã hết hạn' });
  }
  if (record.otp !== otp) return res.status(400).json({ error: 'OTP không đúng' });
  delete otpStore[email];
  res.json({ success: true, message: 'Đăng nhập thành công!' });
});

app.listen(process.env.PORT, () => {
  console.log('Server chạy tại http://localhost:' + process.env.PORT);
});