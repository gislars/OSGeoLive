# -*- coding: utf-8 -*-
#############################################################################
#
# OSGeoLive pycsw WSGI entry point.
# Runs under mod_wsgi with python-home=/opt/osgeolive-venv (see apache-pycsw.conf).
#
#############################################################################

import gzip
from io import BytesIO
import os
from urllib.parse import unquote

import configparser

from pycsw import server

PYCSW_ROOT_DEFAULT = "/usr/share/pycsw"
PYCSW_CONFIG_DEFAULT = "/etc/pycsw/default.cfg"


def application(env, start_response):
    """WSGI wrapper for pycsw."""
    pycsw_root = get_pycsw_root_path(os.environ, env)
    configuration_path = get_configuration_path(os.environ, env, pycsw_root)
    env["local.app_root"] = pycsw_root
    if "HTTP_HOST" in env and ":" in env["HTTP_HOST"]:
        env["HTTP_HOST"] = env["HTTP_HOST"].split(":")[0]

    csw = server.Csw(configuration_path, env)
    status, contents = csw.dispatch_wsgi()
    headers = {
        "Content-Length": str(len(contents)),
        "Content-Type": str(csw.contenttype),
    }
    if "gzip" in env.get("HTTP_ACCEPT_ENCODING", ""):
        try:
            compression_level = int(
                csw.config.get("server", "gzip_compresslevel")
            )
            contents, compress_headers = compress_response(
                contents, compression_level
            )
            headers.update(compress_headers)
        except (configparser.NoOptionError, configparser.NoSectionError):
            pass

    start_response(status, list(headers.items()))
    return [contents]


def compress_response(response, compression_level):
    buf = BytesIO()
    gzipfile = gzip.GzipFile(
        mode="wb", fileobj=buf, compresslevel=compression_level
    )
    gzipfile.write(response)
    gzipfile.close()
    return buf.getvalue(), {"Content-Encoding": "gzip"}


def get_pycsw_root_path(
    process_environment,
    request_environment=None,
    root_path_key="PYCSW_ROOT",
):
    """Resolve pycsw root; Deb-layout default is /usr/share/pycsw."""
    req_env = dict(request_environment) if request_environment is not None else {}
    return process_environment.get(
        root_path_key,
        req_env.get(root_path_key, PYCSW_ROOT_DEFAULT),
    )


def get_configuration_path(
    process_environment,
    request_environment,
    pycsw_root,
    config_path_key="PYCSW_CONFIG",
):
    """Resolve config path; prefer PYCSW_CONFIG, else /etc/pycsw/default.cfg."""
    query_string = request_environment.get("QUERY_STRING", "").lower()
    for kvp in query_string.split("&"):
        if "config" in kvp:
            return unquote(kvp.split("=", 1)[1])

    return process_environment.get(
        config_path_key,
        request_environment.get(config_path_key, PYCSW_CONFIG_DEFAULT),
    )
