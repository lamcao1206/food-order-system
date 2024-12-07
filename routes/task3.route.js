import express from 'express';
const router = express.Router();
import Task3Controller from '../controllers/task3.controller.js';

router.get('/', Task3Controller.index);
router.post('/', Task3Controller.postResult);
export default router;
