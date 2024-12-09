import express from 'express';
import task1 from './task1.route.js';
import task2 from './task2.route.js';
import task3 from './task3.route.js';

const router = express.Router();

router.get('/test', (req, res) => {
  res.send('API working fine!');
});

router.get('/', (req, res, next) => {
  res.render('index', { title: 'Express' });
});

router.get('/task2',(req,res,next)=> {
  res.render('task2',{ title: 'Express' })
})

router.use('/fooditem', task1);
router.use('/api/task2', task2);
router.use('/task3', task3);

export default router;
