from flask import Blueprint, render_template, flash, redirect, url_for
from flask_nav.elements import Navbar, View, Subgroup, Link, Text, Separator
import subprocess as sub
from markupsafe import escape

from .nav import nav

frontend = Blueprint('frontend', __name__)

nav.register_element('frontend_top', Navbar(
    Link('View stream', 'http://raspberrypi.local:8081'),
    View('Open the gatezz', '.open')
    ))

@frontend.route('/')

def index():
    return render_template('index.html')

@frontend.route('/open')
def open():
    p = sub.Popen('switch', stdout = sub.PIPE, stderr=sub.PIPE, stdin=sub.PIPE)
    out,err = p.communicate()
    return out

