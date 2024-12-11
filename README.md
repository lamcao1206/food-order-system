# FOOD ORDER SYSTEM 

### Prerequisite
- MySQL >= 8.4.0
- NodeJS >= 23.3.0

### Setting 
- Run the final_script.sql in MySQL Workbench or MySQL CLI to set up the database and insert sample data into it.
- Make a ```config.env``` file and prepare the following information in the file:
```
PORT=3000
MODE=dev

DB_HOST=localhost
DB_USER=root
DB_DATABASE=food_ordering_db
DB_PASSWORD=<your_database_server_password>
```

- Go to the src folder and run ```npm start```
