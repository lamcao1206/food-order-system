import express from 'express';
import Task2 from '../controllers/task2.controller.js';

const router = express.Router();

router.get('/:ID',Task2.prototype.getordersswithdiscount);
router.get('/',Task2.prototype.getcustomerID);
router.delete('/:ID',Task2.prototype.deleteOrderID);

export default router;
