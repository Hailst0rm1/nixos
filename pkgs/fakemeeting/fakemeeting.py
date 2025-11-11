import time
import codecs
import smtplib
import datetime
import sys
import argparse
import os
from email.mime.text import MIMEText
from email.mime.base import MIMEBase
from email.encoders import encode_base64
from email.mime.multipart import MIMEMultipart
from email.utils import COMMASPACE, formatdate


# Get the directory where this script is located (for finding templates)
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))

# Default values
DEFAULT_EMAIL_SUBJECT = "HR Meeting"
DEFAULT_EVENT_SUMMARY = "HR meeting"
DEFAULT_ORGANIZER_NAME = "HR Team Corp1"
DEFAULT_ATTENDEES = ["ceo@corp1.com", "cto@corp1.com"]
DEFAULT_EVENT_TEXT = """
Dear colleague,

We would like to inform you about an important HR meeting regarding recent company-wide changes and policies. Your attendance is highly encouraged as we will be discussing essential updates that impact all employees.

Topics will include:

- Organizational restructuring
- New employee benefits package
- Updates to leave policies
- Changes to the remote work policy

This meeting is a priority and will be your opportunity to ask any questions or raise concerns.

We look forward to your participation.

Best regards,
HR Team
"""

def load_template():
    template = ""
    template_path = os.path.join(SCRIPT_DIR, "email_template.html")
    with codecs.open(template_path, 'r', 'utf-8') as f:
        template = f.read()
    return template


def prepare_template(event_url, event_text):
    email_template = load_template()
    email_template = email_template.format(EVENT_TEXT=event_text, EVENT_URL=event_url)
    return email_template


def load_ics():
    ics = ""
    ics_path = os.path.join(SCRIPT_DIR, "iCalendar_template.ics")
    with codecs.open(ics_path, 'r', 'utf-8') as f:
        ics = f.read()
    return ics


def prepare_ics(dtstamp, dtstart, dtend, sender_email, event_url, event_summary, organizer_name, attendees):
    ics_template = load_ics()
    ics_template = ics_template.format(
        DTSTAMP=dtstamp,
        DTSTART=dtstart,
        DTEND=dtend,
        ORGANIZER_NAME=organizer_name,
        ORGANIZER_EMAIL=sender_email,
        DESCRIPTION=event_url,  # Use event_url as DESCRIPTION
        SUMMARY=event_summary,
        ATTENDEES=generate_attendees(attendees)
    )
    return ics_template


def generate_attendees(attendees):
    attendees_list = []
    for attendee in attendees:
        attendees_list.append(
            "ATTENDEE;CUTYPE=INDIVIDUAL;ROLE=REQ-PARTICIPANT;PARTSTAT=ACCEPTED;RSVP=FALSE\r\n ;CN={attendee};X-NUM-GUESTS=0:\r\n mailto:{attendee}".format(attendee=attendee)
        )
    return "\r\n".join(attendees_list)


def send_email(smtp_server, sender_email, to, event_url, email_subject, event_summary, organizer_name, attendees, event_text, smtp_port=25, smtp_username=None, smtp_password=None, use_tls=False):
    print('Sending email to: ' + to)

    # in .ics file timezone is set to be utc
    utc_offset = time.localtime().tm_gmtoff / 60
    ddtstart = datetime.datetime.now()
    dtoff = datetime.timedelta(minutes=utc_offset + 5)  # meeting has started 5 minutes ago
    duration = datetime.timedelta(hours=1)  # meeting duration
    ddtstart = ddtstart - dtoff
    dtend = ddtstart + duration
    dtstamp = datetime.datetime.now().strftime("%Y%m%dT%H%M%SZ")
    dtstart = ddtstart.strftime("%Y%m%dT%H%M%SZ")
    dtend = dtend.strftime("%Y%m%dT%H%M%SZ")

    ics = prepare_ics(dtstamp, dtstart, dtend, sender_email, event_url, event_summary, organizer_name, attendees)
    email_body = prepare_template(event_url, event_text)

    msg = MIMEMultipart('mixed')
    msg['Reply-To'] = sender_email
    msg['Date'] = formatdate(localtime=True)
    msg['Subject'] = email_subject
    msg['From'] = sender_email
    msg['To'] = to

    part_email = MIMEText(email_body, "html")
    part_cal = MIMEText(ics, 'calendar;method=REQUEST')

    msgAlternative = MIMEMultipart('alternative')
    msg.attach(msgAlternative)

    ics_atch = MIMEBase('application/ics', ' ;name="%s"' % ("invite.ics"))
    ics_atch.set_payload(ics)
    encode_base64(ics_atch)
    ics_atch.add_header('Content-Disposition', 'attachment; filename="%s"' % ("invite.ics"))

    eml_atch = MIMEBase('text/plain', '')
    eml_atch.set_payload("")
    encode_base64(eml_atch)
    eml_atch.add_header('Content-Transfer-Encoding', "")

    msgAlternative.attach(part_email)
    msgAlternative.attach(part_cal)

    # Connect to SMTP server
    try:
        if use_tls:
            # Use SMTP_SSL for implicit TLS (usually port 465)
            mailServer = smtplib.SMTP_SSL(smtp_server, smtp_port)
        else:
            # Use regular SMTP, optionally with STARTTLS
            mailServer = smtplib.SMTP(smtp_server, smtp_port)
            mailServer.ehlo()
            # Try STARTTLS if port 587 or if credentials are provided
            if smtp_port == 587 or smtp_username:
                try:
                    mailServer.starttls()
                    mailServer.ehlo()
                except:
                    pass  # STARTTLS not supported, continue anyway
        
        # Authenticate if credentials provided
        if smtp_username and smtp_password:
            mailServer.login(smtp_username, smtp_password)
        
        mailServer.sendmail(sender_email, to, msg.as_string())
        mailServer.close()
        print("Email sent successfully!")
    except Exception as e:
        print(f"Error sending email: {e}")
        sys.exit(1)


def main():
    parser = argparse.ArgumentParser(
        description='Send fake calendar meeting invitations via SMTP',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog='''
Examples:
  # Basic unauthenticated SMTP (port 25)
  fakemeeting -s smtp.example.com -f hr@corp1.com -t user@corp1.com -u https://meet.example.com/abc123

  # With authentication (STARTTLS on port 587)
  fakemeeting -s smtp.gmail.com -p 587 -f hr@corp1.com -t user@corp1.com -u https://meet.example.com/abc123 \\
    --smtp-user hr@corp1.com --smtp-pass "yourpassword"

  # With TLS (implicit TLS on port 465)
  fakemeeting -s smtp.gmail.com -p 465 --tls -f hr@corp1.com -t user@corp1.com -u https://meet.example.com/abc123 \\
    --smtp-user hr@corp1.com --smtp-pass "yourpassword"

  # With custom content and attendees
  fakemeeting -s smtp.example.com -f hr@corp1.com -t user@corp1.com -u https://meet.example.com/abc123 \\
    --subject "Urgent: Security Update" --summary "Security Meeting" --organizer "IT Security Team"
  
  # With custom message from file
  fakemeeting -s smtp.example.com -f hr@corp1.com -t user@corp1.com -u https://meet.example.com/abc123 \\
    --event-text-file custom_message.txt --attendees admin@corp1.com,ceo@corp1.com
        '''
    )
    
    # Required arguments
    parser.add_argument('-s', '--smtp-server', required=True,
                        help='SMTP server address')
    parser.add_argument('-f', '--from', dest='sender_email', required=True,
                        help='Sender email address')
    parser.add_argument('-t', '--to', dest='recipient_email', required=True,
                        help='Recipient email address')
    parser.add_argument('-u', '--url', dest='event_url', required=True,
                        help='Meeting URL/link')
    
    # SMTP configuration
    parser.add_argument('-p', '--port', dest='smtp_port', type=int, default=25,
                        help='SMTP port (default: 25, common: 587 for STARTTLS, 465 for TLS)')
    parser.add_argument('--smtp-user', dest='smtp_username', default=None,
                        help='SMTP username for authentication')
    parser.add_argument('--smtp-pass', dest='smtp_password', default=None,
                        help='SMTP password for authentication')
    parser.add_argument('--tls', dest='use_tls', action='store_true',
                        help='Use implicit TLS (SMTP_SSL, typically port 465)')
    
    # Optional arguments with defaults
    parser.add_argument('--subject', dest='email_subject', default=DEFAULT_EMAIL_SUBJECT,
                        help=f'Email subject (default: "{DEFAULT_EMAIL_SUBJECT}")')
    parser.add_argument('--summary', dest='event_summary', default=DEFAULT_EVENT_SUMMARY,
                        help=f'Event summary/title (default: "{DEFAULT_EVENT_SUMMARY}")')
    parser.add_argument('--organizer', dest='organizer_name', default=DEFAULT_ORGANIZER_NAME,
                        help=f'Organizer name (default: "{DEFAULT_ORGANIZER_NAME}")')
    parser.add_argument('--attendees', dest='attendees', default=','.join(DEFAULT_ATTENDEES),
                        help=f'Comma-separated list of attendee emails (default: "{",".join(DEFAULT_ATTENDEES)}")')
    
    # Event text - either direct or from file
    event_text_group = parser.add_mutually_exclusive_group()
    event_text_group.add_argument('--event-text', dest='event_text', default=None,
                                   help='Event description text')
    event_text_group.add_argument('--event-text-file', dest='event_text_file', default=None,
                                   help='File containing event description text')
    
    args = parser.parse_args()
    
    # Process attendees list
    attendees_list = [email.strip() for email in args.attendees.split(',')]
    
    # Process event text
    if args.event_text_file:
        # Resolve relative paths
        file_path = os.path.abspath(os.path.expanduser(args.event_text_file))
        try:
            with codecs.open(file_path, 'r', 'utf-8') as f:
                event_text = f.read()
        except FileNotFoundError:
            print(f"Error: File '{args.event_text_file}' not found")
            sys.exit(1)
        except Exception as e:
            print(f"Error reading file '{args.event_text_file}': {e}")
            sys.exit(1)
    elif args.event_text:
        event_text = args.event_text
    else:
        event_text = DEFAULT_EVENT_TEXT
    
    send_email(
        args.smtp_server,
        args.sender_email,
        args.recipient_email,
        args.event_url,
        args.email_subject,
        args.event_summary,
        args.organizer_name,
        attendees_list,
        event_text,
        smtp_port=args.smtp_port,
        smtp_username=args.smtp_username,
        smtp_password=args.smtp_password,
        use_tls=args.use_tls
    )


if __name__ == "__main__":
    main()
