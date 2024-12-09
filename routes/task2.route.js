import express from 'express';
import Task2 from '../controllers/task2.controller.js';

const router = express.Router();

//Task 2.1
router.get('/orderswithdiscount/:ID',Task2.prototype.getorderswithdiscount);
router.get('/customerid',Task2.prototype.getcustomerID);

//Task 2.2 
router.get('/ordersbycategory/:ID',Task2.prototype.getordersbycategory);
router.get('/categoryid',Task2.prototype.getcategoryID);


router.delete('/:ID',Task2.prototype.deleteOrderID);

export default router;
