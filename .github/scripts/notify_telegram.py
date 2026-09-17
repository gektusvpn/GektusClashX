#!/usr/bin/env python3
import html
import os
import sys

import requests


def send_telegram_message(bot_token, chat_id, message, parse_mode='HTML'):
    """Send a message to a Telegram chat."""
    url = f"https://api.telegram.org/bot{bot_token}/sendMessage"
    payload = {
        'chat_id': chat_id,
        'text': message,
        'parse_mode': parse_mode,
        'disable_web_page_preview': False,
    }

    try:
        response = requests.post(url, json=payload, timeout=30)
        response.raise_for_status()
        return True
    except requests.exceptions.RequestException as error:
        # Telegram's JSON description explains configuration errors without
        # exposing the bot token or destination identifier.
        description = type(error).__name__
        if error.response is not None:
            try:
                description = error.response.json().get(
                    'description',
                    description,
                )
            except requests.exceptions.JSONDecodeError:
                description = f"HTTP {error.response.status_code}"

        annotation = str(description).replace('%', '%25')
        annotation = annotation.replace('\r', '%0D').replace('\n', '%0A')
        print(f"Error sending message to Telegram chat: {description}")
        print(f"::error title=Telegram notification failed::{annotation}")
        return False


def format_release_message(version, commits, release_url, is_stable):
    """Format the release notification message using Telegram HTML."""
    version_clean = html.escape(version.lstrip('v'))
    emoji = "🎉" if is_stable else "🚀"
    release_type = (
        "GektusClashX. Stable Version on GitHub"
        if is_stable
        else "GektusClashX. PreRelease Version on GitHub"
    )

    message = f"{emoji} <b>{version_clean} in GitHub!</b> {emoji}\n\n"
    message += f"<i>{release_type}</i>\n\n"
    message += "<b>Whats new:</b>\n"
    message += html.escape(commits) + "\n"
    message += f'🔗 <a href="{html.escape(release_url)}">DOWNLOAD</a>\n'
    return message


def main():
    bot_token = os.environ.get('TELEGRAM_BOT_TOKEN')
    chat_id = os.environ.get('TELEGRAM_CHAT_ID')
    version = os.environ.get('VERSION')
    commits = os.environ.get('COMMITS')
    release_url = os.environ.get('RELEASE_URL')
    is_stable = os.environ.get('IS_STABLE', 'false').lower() == 'true'

    if not all([bot_token, chat_id, version, commits, release_url]):
        print("Error: Missing required environment variables")
        print(f"TELEGRAM_BOT_TOKEN: {'✓' if bot_token else '✗'}")
        print(f"TELEGRAM_CHAT_ID: {'✓' if chat_id else '✗'}")
        print(f"VERSION: {'✓' if version else '✗'}")
        print(f"COMMITS: {'✓' if commits else '✗'}")
        print(f"RELEASE_URL: {'✓' if release_url else '✗'}")
        sys.exit(1)

    message = format_release_message(version, commits, release_url, is_stable)

    # Log notification details without the bot token or destination identifier.
    print(f"Sending notification for version {version}...")
    print(f"Release URL: {release_url}")
    print(f"Release type: {'Stable' if is_stable else 'Pre-release'}")
    print(
        f"\nFull message preview (first 200 chars):\n{'-'*50}\n"
        f"{message[:200]}...\n{'-'*50}\n"
    )

    if not send_telegram_message(bot_token, chat_id, message):
        print("✗ Telegram notification failed")
        sys.exit(1)

    print("✓ Telegram notification sent successfully")


if __name__ == '__main__':
    main()
