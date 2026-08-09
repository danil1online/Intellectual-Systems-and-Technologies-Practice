"""
Custom logout handler for JupyterHub.
Redirects to Keycloak logout endpoint with id_token_hint and post_logout_redirect_uri.
"""

from tornado.web import authenticated
from jupyterhub.handlers.base import BaseHandler
from urllib.parse import urlencode, urlparse, urlunparse
import os


class KeycloakLogoutHandler(BaseHandler):
    """
    Custom logout handler that:
    1. Ends the JupyterHub session (clears cookies)
    2. Redirects to Keycloak logout endpoint with id_token_hint
    3. After Keycloak logout, redirects to /hub/login
    """
    
    @authenticated
    def get(self):
        # Get the current user's id_token_hint if available
        # In JupyterHub with GenericOAuthenticator, the id_token is stored in the user's auth state
        user = self.current_user
        id_token_hint = None
        
        if user and user.server:
            # Try to get id_token from user's auth state
            try:
                auth_state = yield user.get_auth_state()
                if auth_state and 'id_token' in auth_state:
                    id_token_hint = auth_state['id_token']
            except Exception:
                pass
        
        # Build the Keycloak logout URL
        keycloak_url = os.environ.get('KEYCLOAK_URL', f"http://{os.environ.get('HOST_IP', '10.8.1.3')}:{os.environ.get('KEYCLOAK_PORT', '9200')}")
        logout_url = f"{keycloak_url}/auth/realms/istp/protocol/openid-connect/logout"
        
        # Add id_token_hint if available (required for automatic logout without confirmation)
        params = {
            'post_logout_redirect_uri': f"http://{os.environ.get('HOST_IP', '10.8.1.3')}:{os.environ.get('JUPYTERHUB_PORT', '8000')}/hub/login"
        }
        
        if id_token_hint:
            params['id_token_hint'] = id_token_hint
        
        # URL-encode the params
        query_string = urlencode(params)
        logout_url = f"{logout_url}?{query_string}"
        
        # Clear the JupyterHub session cookie
        self.clear_cookie("_jupyterhub_user", path="/")
        self.clear_cookie("_jupyterhub_nonce", path="/")
        self.clear_cookie("_jupyterhub_auth_state", path="/")
        
        # Redirect to Keycloak logout
        self.redirect(logout_url)
