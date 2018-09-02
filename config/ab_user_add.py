import airflow
from airflow.www_rbac.app import cached_appbuilder

username='airflow'
firstname='Airflow'
lastname='Admin'
email='airflow@fab_airflow.com'
role_str='Admin'
password='airflow'

appbuilder = cached_appbuilder()
role = appbuilder.sm.find_role(role_str)
if appbuilder.sm.find_user(username):
    print('{} already exist in the db'.format(username))
else:
    user = appbuilder.sm.add_user(username, firstname, lastname, email, role, password)
    if user:
        print('{} user {} created.'.format(role, username))