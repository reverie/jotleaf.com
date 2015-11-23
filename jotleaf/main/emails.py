from django.core.mail import EmailMultiAlternatives
from django.core.signing import Signer
from django.core.urlresolvers import reverse
from django.template.loader import render_to_string

from main.models import CustomUser as User
from main.templatetags.main_tags import make_path_absolute

def abs_reverse(view_name, **kwargs):
    path = reverse(view_name, **kwargs)
    return make_path_absolute(path)

def generate_unsubscribe_url(user, email_type):
    signer = Signer()
    url_path = "/account/settings/unsubscribe/{email_type}/{token}"
    action = '|'.join([str(user.id), user.username, 'unsubscribe', email_type])
    token = signer.sign(action)
    path = url_path.format(email_type=email_type, token=token)
    return make_path_absolute(path)

def get_text_template(email_name):
    return 'emails/%s.txt' % email_name

def get_html_template(email_name):
    return 'emails/%s.html' % email_name

def prep_follow_email(target, follow):
    assert target == follow.target
    user = follow.user
    target = follow.target
    subject = "{target}, {user} is now following you on Jotleaf!".format(user=user.username, target=target.username)

    # TODO: use new helpers for these in template
    listed_pages = user.listed_pages()
    num_listed_pages = listed_pages.count()
    sample_pages = listed_pages.order_by('-published_at')[:3]

    context = {
        'subject': subject,
        'user': user,
        'target': target,
        'unsubscribe_url': generate_unsubscribe_url(target, 'follow'),
        'preferences_url': abs_reverse('settings'),
        'num_listed_pages': num_listed_pages,
        'sample_pages': sample_pages
    }
    return subject, context

def prep_multifollow_email(target, follows):
    subject = "{target.username}, you have new followers on Jotleaf!".format(target=target)
    context = {
        'subject': subject,
        'target': target,
        'followers': follows,
        'unsubscribe_url': generate_unsubscribe_url(target, 'follow'),
        'preferences_url': abs_reverse('settings'),
    }
    return subject, context

def prep_member_email(user, membership):
    assert user == membership.user
    page = membership.page
    owner = page.owner
    title = page.title
    args = dict(user=user.username, owner=getattr(owner, 'username', ''), title=title)
    if owner and title:
        subject = "{user}, you were added by {owner} to their Jotleaf page '{title}'".format(**args)
    elif owner:
        subject = "{user}, you were added to a Jotleaf page by {owner}".format(**args)
    elif title:
        subject = "{user}, you were added to the Jotleaf page '{title}'".format(**args)
    else:
        subject = "{user}, you were added to a Jotleaf page".format(**args)
    context = {
        'subject': subject,
        'user': user,
        'owner': owner,
        'page': page,
        'title': title,
        'unsubscribe_url': generate_unsubscribe_url(user, 'member'),
        'preferences_url': abs_reverse('settings'),
    }
    return subject, context

def prep_multimember_email(user, memberships):
    subject = "{user.username}, you were added to new pages on Jotleaf!".format(user=user)
    context = {
        'subject': subject,
        'user': user,
        'memberships': memberships,
        'unsubscribe_url': generate_unsubscribe_url(user, 'member'),
        'preferences_url': abs_reverse('settings'),
    }
    return subject, context

def fake_context(email_name):
    from main.models import Follow, Membership
    if email_name == 'follow':
        f = Follow.objects.all()[0]
        return prep_follow_email(f.target, f)[1]
    elif email_name == 'multifollow':
        target = User.objects.get(username='andrew')
        follows = target.followers.all()
        return prep_multifollow_email(target, follows)
    elif email_name == 'member':
        m = Membership.objects.all()[0]
        return prep_member_email(m.user, m)[1]
    elif email_name == 'multimember':
        user = User.objects.get(username='andrew')
        memberships = user.membership_set.all()
        return prep_multimember_email(user, memberships)[1]

def preview_email(email_name):
    template_path = 'emails/{}.html'.format(email_name)
    context = fake_context(email_name)
    return render_to_string(template_path, context)

def prep_email(email_name, *args):
    if email_name == 'follow':
        return prep_follow_email(*args)
    elif email_name == 'multifollow':
        return prep_multifollow_email(*args)
    elif email_name == 'member':
        return prep_member_email(*args)
    elif email_name == 'multimember':
        return prep_multimember_email(*args)
    raise ValueError("Unknown email_name %s" % email_name)

def send_email(email_name, to, *args):
    text_template = get_text_template(email_name)
    html_template = get_html_template(email_name)
    subject, context = prep_email(email_name, *args)
    text_body = render_to_string(text_template, context)
    html_body = render_to_string(html_template, context)
    bcc = ['andrew@jotleaf.com']
    msg = EmailMultiAlternatives(
        subject=subject,
        body=text_body,
        to=to,
        bcc=bcc
    )
    msg.attach_alternative(html_body, 'text/html')
    msg.send()

def send_follow_email(target, follow):
    send_email('follow', [target.email], target, follow)

def send_multifollow_email(target, follows):
    send_email('multifollow', [target.email], target, follows)

def send_member_email(user, membership):
    send_email('member', [user.email], user, membership)

def send_multimember_email(user, memberships):
    send_email('multimember', [user.email], user, memberships)

def send_shutdown_email(user):
    subject = "Jotleaf is shutting down"
    context = {
        'username': user.username,
        'date_joined': user.date_joined.strftime("%B %d, %Y"),
    }
    text_body = render_to_string('emails/shutdown.txt', context)
    msg = EmailMultiAlternatives(
        subject=subject,
        body=text_body,
        to=[user.email],
    )
    msg.send(fail_silently=True)
