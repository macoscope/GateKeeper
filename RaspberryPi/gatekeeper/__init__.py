from flask import Flask
from flask_appconfig import AppConfig
from flask_bootstrap import Bootstrap
from workzeug.contrib.fixers import ProxyFix

from .frontend import frontend
from .nav import nav


app = Flask(__name__)

AppConfig(app)

Bootstrap(app)

app.register_blueprint(frontend)

app.config['BOOTSTRAP_SERVE_LOCAL'] = True

nav.init_app(app)

app.wsgi_app = ProxyFix(app.wsgi_app)

if __name__ == '__main__':
    app.run()
