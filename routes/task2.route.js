import express from 'express';
import Task2 from '../controllers/task2.controller.js';

const router = express.Router();

router.get('/:ID',Task2.prototype.getdata);


export default router;
