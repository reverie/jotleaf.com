from django import forms
from django.contrib.auth.forms import AuthenticationForm
from django.core.exceptions import MultipleObjectsReturned
from django.forms import ModelForm

from main.models import Page


class CreatePageForm(ModelForm):
    title = forms.CharField(
        max_length=50,
        widget=forms.TextInput(attrs={
            'placeholder': 'Title of New Page',
            'maxlength': 50,
            'size': 50,
        }),
    )
    class Meta:
        model = Page
        fields = ['title']

class CustomAuthForm(AuthenticationForm):
	""" 
	Copied over from base class AuthenticationForm, via YWOT
	Added non-unique email checking functionality to raise an appropriate validation ValidationError
	"""

	def clean(self):
		try:
			cleaned_data = super(CustomAuthForm, self).clean()

		# a username/password validation error has been encountered, override default case sensitive message	
		except forms.ValidationError:
			raise forms.ValidationError("Your username and password didn't match. Please try again.")
		except MultipleObjectsReturned:
			raise forms.ValidationError('There are multiple users registered with that email. Please sign in with a username.')
		return cleaned_data
