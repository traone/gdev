create database `foobarnakki`;
CREATE USER `foobarnakki`@`%` IDENTIFIED BY 'strongpassword';
grant all privileges on `foobarnakki`.* to `foobarnakki`@`%`;
flush privileges;
