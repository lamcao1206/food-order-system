import pool from '../configs/db.config.js';

export default class Task3Controller {
  static index(req, res, next) {
    res.render('task3', { title: 'Task 3', result: null, message: null, error: null, list: null });
  }

  static async postResult(req, res, next) {
    const { restaurantName, categoryId } = req.body;
    console.log(restaurantName, categoryId);
    try {
      const [counting] = await pool.execute('SELECT count_food(?, ?) AS total_food', [restaurantName, categoryId]);
      const [list] = await pool.execute('SELECT * FROM foods WHERE restaurant_name = ? AND category_id = ?', [restaurantName, categoryId]);
      res.render('task3', { title: 'Task 3', result: counting[0].total_food, error: null, message: null, list: null });
    } catch (err) {
      console.log(err);
      res.render('task3', { title: 'Task 3', result: null, message: 'An error occurred while processing your request', error: err.message, list: null });
    }
  }
}
