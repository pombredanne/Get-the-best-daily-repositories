from flask import Flask, render_template
from flask_socketio import SocketIO
from logger import logger
import os
from api.music_api import MusicAPI
from api.books_api import BooksAPI
from api.shows_api import ShowsAPI
from api.movies_api import MoviesAPI
from api.settings_api import SettingsAPI
from api.tasks_api import TasksAPI
from api.logs_api import LogsAPI
from api.downloads_api import DownloadsAPI
from api.subscriptions_api import SubscriptionsAPI
from services.lidarr_services import LidarrService
from services.radarr_services import RadarrService
from services.readarr_services import ReadarrService
from services.sonarr_services import SonarrService
from services.spotify_services import SpotifyService
from services.spotdl_download_services import SpotDLDownloadService
from services.config_services import Config
from db.music_db_handler import MusicDBHandler


class MediaWolfApp:
    def __init__(self, host="0.0.0.0", port=5000):
        self.spotdl_download_history = {}
        self.host = host
        self.port = port

        base_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
        template_path = os.path.join(base_dir, os.path.join("frontend", "templates"))
        static_path = os.path.join(base_dir, os.path.join("frontend", "static"))

        self.app = Flask(__name__, template_folder=template_path, static_folder=static_path)
        self.socketio = SocketIO(self.app, cors_allowed_origins="*")

        self.music_db = MusicDBHandler()
        self.config = Config()
        self.lidarr_service = LidarrService(self.config, self.music_db)
        self.sonarr_service = SonarrService()
        self.radarr_service = RadarrService()
        self.readarr_service = ReadarrService()
        self.spotdl_download_service = SpotDLDownloadService(self.config, self.spotdl_download_history)
        self.spotify_service = SpotifyService(self.config)
        self.readarr_service = ()

        self.music_api = MusicAPI(self.music_db, self.socketio, self.lidarr_service, self.spotify_service, self.spotdl_download_service)
        self.books_api = BooksAPI(self.music_db, self.socketio, self.readarr_service)
        self.movies_api = MoviesAPI(self.music_db, self.socketio, self.radarr_service)
        self.shows_api = ShowsAPI(self.music_db, self.socketio, self.sonarr_service)
        self.downloads_api = DownloadsAPI(self.socketio)
        self.subscriptions_api = SubscriptionsAPI(self.socketio)
        self.settings_api = SettingsAPI(self.music_db, self.socketio, self.config)
        self.tasks_api = TasksAPI(self.socketio, self.lidarr_service, self.radarr_service, self.readarr_service, self.sonarr_service)
        self.logs_api = LogsAPI(self.socketio)

        self.add_routes()
        self.setup_socket_events()

    def add_routes(self):
        """Define Flask routes."""
        self.app.register_blueprint(self.books_api.get_blueprint())
        self.app.register_blueprint(self.movies_api.get_blueprint())
        self.app.register_blueprint(self.shows_api.get_blueprint())
        self.app.register_blueprint(self.music_api.get_blueprint())
        self.app.register_blueprint(self.downloads_api.get_blueprint())
        self.app.register_blueprint(self.subscriptions_api.get_blueprint())
        self.app.register_blueprint(self.settings_api.get_blueprint())
        self.app.register_blueprint(self.tasks_api.get_blueprint())
        self.app.register_blueprint(self.logs_api.get_blueprint())

        @self.app.route("/")
        def home():
            artists_for_selection = self.music_db.get_existing_db_artists()
            sorted_artists = [artist.title() for artist in sorted(artists_for_selection)]
            return render_template("music.html", artists=sorted_artists)

    def setup_socket_events(self):
        """Set up Socket.IO events."""

        @self.socketio.on("connect")
        def handle_connect():
            logger.info("Client connected")

        @self.socketio.on("disconnect")
        def handle_disconnect():
            logger.info("Client disconnected")

    def run(self):
        """Run Flask app with SocketIO."""
        self.socketio.run(self.app, host=self.host, port=self.port)


if __name__ == "__main__":
    media_wolf_app = MediaWolfApp()
    media_wolf_app.run()
