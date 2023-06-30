npx sequelize-cli seed:generate --name demo-category
npx sequelize-cli seed:generate --name demo-ecosystem
npx sequelize-cli seed:generate --name demo-user
npx sequelize-cli seed:generate --name demo-project


npx sequelize db:seed:all

npx sequelize-cli db:seed:undo:all

npx sequelize migration:create --name create-users

npx sequelize-cli db:migrate