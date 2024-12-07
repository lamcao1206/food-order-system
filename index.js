import express from 'express';
import router from './routes/index.js';
import pool from './configs/db.config.js';

const port = process.env.PORT || 3000;
const app = express();

app.set('view engine', 'ejs');
app.set('views', 'views');
app.use(express.static('public'));
app.use(express.urlencoded({ extended: true }));
app.use(express.json()); 

app.use('/', router);

app.listen(port, () => {
  console.log(`Server is running on port ${port}...`);
});
