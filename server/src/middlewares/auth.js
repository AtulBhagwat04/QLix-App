import jwt from 'jsonwebtoken';
import dotenv from 'dotenv';
import { AppError } from './errorHandler.js';

dotenv.config();

const JWT_SECRET = process.env.JWT_SECRET || 'supersecretjwtkeyforqlixauth';

export const protectHost = (req, res, next) => {
  try {
    let token;
    if (req.headers.authorization && req.headers.authorization.startsWith('Bearer')) {
      token = req.headers.authorization.split(' ')[1];
    }

    if (!token) {
      return next(new AppError('You are not logged in. Please log in to get access.', 401));
    }

    // Verify token
    jwt.verify(token, JWT_SECRET, (err, decoded) => {
      if (err) {
        if (err.name === 'TokenExpiredError') {
          return next(new AppError('Token expired. Please refresh your token.', 401));
        }
        return next(new AppError('Invalid token. Please log in again.', 401));
      }

      req.user = {
        id: decoded.id,
        email: decoded.email,
        name: decoded.name,
      };
      next();
    });
  } catch (error) {
    next(error);
  }
};
