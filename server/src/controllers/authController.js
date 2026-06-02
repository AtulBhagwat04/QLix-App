import bcrypt from 'bcryptjs';
import jwt from 'jsonwebtoken';
import db from '../config/db.js';
import { AppError } from '../middlewares/errorHandler.js';

const JWT_SECRET = process.env.JWT_SECRET || 'supersecretjwtkeyforqlixauth';
const JWT_EXPIRES_IN = '1d';
const JWT_REFRESH_SECRET = process.env.JWT_REFRESH_SECRET || 'supersecretjwtrefreshkeyforqlixauth';
const JWT_REFRESH_EXPIRES_IN = '7d';

const generateTokens = (user) => {
  const accessToken = jwt.sign(
    { id: user.id, email: user.email, name: user.full_name },
    JWT_SECRET,
    { expiresIn: JWT_EXPIRES_IN }
  );

  const refreshToken = jwt.sign(
    { id: user.id },
    JWT_REFRESH_SECRET,
    { expiresIn: JWT_REFRESH_EXPIRES_IN }
  );

  return { accessToken, refreshToken };
};

export const signup = async (req, res, next) => {
  const { email, password, fullName } = req.body;

  try {
    // Check if user exists
    const checkUser = await db.query('SELECT * FROM users WHERE email = $1', [email]);
    if (checkUser.rows.length > 0) {
      return next(new AppError('Email already registered', 400));
    }

    // Hash password
    const salt = await bcrypt.genSalt(10);
    const passwordHash = await bcrypt.hash(password, salt);

    // Insert user
    const newUser = await db.query(
      'INSERT INTO users (email, password_hash, full_name) VALUES ($1, $2, $3) RETURNING id, email, full_name, created_at',
      [email, passwordHash, fullName]
    );

    const user = newUser.rows[0];
    const { accessToken, refreshToken } = generateTokens(user);

    res.status(201).json({
      status: 'success',
      data: {
        user,
        accessToken,
        refreshToken,
      },
    });
  } catch (error) {
    next(error);
  }
};

export const login = async (req, res, next) => {
  const { email, password } = req.body;

  try {
    const result = await db.query('SELECT * FROM users WHERE email = $1', [email]);
    const user = result.rows[0];

    if (!user || !(await bcrypt.compare(password, user.password_hash))) {
      return next(new AppError('Incorrect email or password', 401));
    }

    const { accessToken, refreshToken } = generateTokens(user);

    res.status(200).json({
      status: 'success',
      data: {
        user: {
          id: user.id,
          email: user.email,
          fullName: user.full_name,
          createdAt: user.created_at,
        },
        accessToken,
        refreshToken,
      },
    });
  } catch (error) {
    next(error);
  }
};

export const refreshToken = async (req, res, next) => {
  const { refreshToken } = req.body;

  if (!refreshToken) {
    return next(new AppError('Refresh token is required', 400));
  }

  try {
    jwt.verify(refreshToken, JWT_REFRESH_SECRET, async (err, decoded) => {
      if (err) {
        return next(new AppError('Invalid or expired refresh token. Please login again.', 401));
      }

      const result = await db.query('SELECT * FROM users WHERE id = $1', [decoded.id]);
      const user = result.rows[0];

      if (!user) {
        return next(new AppError('User belonging to this token no longer exists.', 401));
      }

      const tokens = generateTokens(user);

      res.status(200).json({
        status: 'success',
        data: {
          accessToken: tokens.accessToken,
          refreshToken: tokens.refreshToken,
        },
      });
    });
  } catch (error) {
    next(error);
  }
};
