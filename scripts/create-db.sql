create database `client-asiakas`;
CREATE USER `client-asiakas`@`%` IDENTIFIED BY 'strongpassword';
grant all privileges on `client-asiakas`.* to `client-asiakas`@`%`;
flush privileges;
