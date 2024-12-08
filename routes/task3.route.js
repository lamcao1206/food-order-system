import express from 'express';
const router = express.Router();
import Task3Controller from '../controllers/task3.controller.js';

router.get('/', Task3Controller.index);
router.post('/1', Task3Controller.postResultOne);
router.post('/2', Task3Controller.postResultTwo);
export default router;
