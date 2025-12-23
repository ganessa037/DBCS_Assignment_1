from flask import request, render_template

def configure_security_headers(app):

    @app.after_request
    def add_security_headers(response):
        # cache control headers
        response.headers['Cache-Control'] = 'no-store, no-cache, must-revalidate, max-age=0'
        response.headers['Pragma'] = 'no-cache'
        response.headers['Expires'] = '0'

        # X-Frame-Options header to prevent clickjacking
        response.headers['X-Content-Type-Options'] = 'nosniff'
        response.headers['X-Frame-Options'] = 'DENY'
        response.headers['X-XSS-Protection'] = '1; mode=block'

        # remove server printing
        response.headers.pop('Server', None)

        # enable HSTS if HTTPS is used
        if request.is_secure:
            response.headers['Strict-Transport-Security'] = 'max-age=31536000; includeSubDomains'

        return response
    
def configure_error_handlers(app):
    
    @app.errorhandler(400)
    def handle_csrf_error(e):
        return render_template('csrf_error.html', message="CSRF token missing or invalid."), 40
