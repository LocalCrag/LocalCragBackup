import os
import smtplib
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText
from pathlib import Path
import sys
import yaml

config = yaml.safe_load(Path(os.path.dirname(os.path.realpath(__file__)) + "/config.yml").read_text())


def send_failure_message(error_logs):
    """
    Mails the captured logs to the configured email receiver.
    """

    message = f"Backup of LocalCrag instance \"{config["instance_name"]}\" failed:\n\n"
    message = message + error_logs

    msg = MIMEMultipart("alternative")
    msg["Subject"] = "LocalCrag backup failed"
    msg["From"] = config["smtp"]["sender"]
    msg["To"] = config["smtp"]["receiver"]
    msg.attach(MIMEText(message, "html"))

    with smtplib.SMTP_SSL(config["smtp"]["host"], config["smtp"]["port"]) as server:
        server.login(config["smtp"]["user"], config["smtp"]["password"])
        server.sendmail(config["smtp"]["sender"], config["smtp"]["receiver"], msg.as_string())
        server.quit()


if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("Usage: python3 send_error_email.py '<error_message>'")
        sys.exit(1)

    error_message = sys.argv[1]
    send_failure_message(error_message)
