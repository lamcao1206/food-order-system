import pool from '../configs/db.config.js';

export default class Task3Controller {
  static index(req, res, next) {
    res.render('task3', {
      title: 'Task 3',
    });
  }

  static async postResultOne(req, res, next) {
    const { restaurantName, categoryId } = req.body;
    try {
      const [result] = await pool.execute('SELECT count_food(?, ?) AS total_food', [restaurantName, categoryId]);
      res.status(200).json({
        total_food: result[0].total_food,
        err: null,
      });
    } catch (err) {
      res.status(401).json({
        total_food: null,
        err: err.message,
      });
    }
  }

  static async postResultTwo(req, res, next) {
    const { restaurantName } = req.body;
    try {
      const [result] = await pool.execute(
        `
      SELECT fi.ID, fi.name, fi.price, categorize_food(r.name, fi.name) AS price_level 
      FROM FOOD_ITEM fi
      JOIN CATEGORY c ON c.ID = fi.categoryID
      JOIN RESTAURANT r ON r.ID = c.RID
      WHERE r.name = ?;
    `,
        [restaurantName]
      );
      res.status(200).json({
        result: result,
        err: null,
      });
    } catch (err) {
      console.log(err);
      res.status(401).json({
        result: null,
        err: err.message,
      });
    }
  }
}
