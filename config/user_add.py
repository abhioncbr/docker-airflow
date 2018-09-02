import airflow
from airflow import models, settings
from airflow.contrib.auth.backends.password_auth import PasswordUser
from flask_bcrypt import generate_password_hash
from sqlalchemy import exists

session = settings.Session()
isUserPresent = not session.query(exists().where(models.User.username=='airflow')).scalar()
if(isUserPresent):
	user = PasswordUser(models.User())
	user.username = 'airflow'
	user.email = 'airflow@fab_airflow.com'
	user.superuser = True
	user._password = generate_password_hash('airflow', 12)
	session.add(user)
	session.commit()
session.close()
exit()