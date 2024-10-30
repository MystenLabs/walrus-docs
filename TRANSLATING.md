# Translation Guidelines

## Translation workflow

### Preparation

It uses [mdbook-i18n-helpers] as a translation framework.
The following tools are required.

- GNU gettext utilities ( `msgmerge` and `msgcat` )
- mdbook-i18n-helpers ( `cargo install mdbook-i18n-helpers` )

### Creating and Updating Translations

Please see the [mdbook-i18n-helpers USAGE] file for the detailed usage of mdbook-i18n-helpers.
The summarized command list is below:

#### Generating a message template

The generated message template `po/messages.pot` is required to create or update translations.

```bash
MDBOOK_OUTPUT='{"xgettext": {"pot-file": "messages.pot"}}' \
  mdbook build -d po
```

#### Creating a new translation resource

`xx` is [ISO 639](https://en.wikipedia.org/wiki/List_of_ISO_639-1_codes) language code.

```bash
msginit -i po/messages.pot -l xx -o po/xx.po
```

#### Updating the existing translation resource

```bash
msgmerge --update po/xx.po po/messages.pot
```

### Editing translation resources

After generating a translation resource `po/xx.po`, you can write translation messages  
in `msgstr` entry of `po/xx.po`.
To build a translated book, the following command can be used.

```bash
MDBOOK_BOOK__LANGUAGE=xx mdbook build
MDBOOK_BOOK__LANGUAGE=xx mdbook serve
```

[mdbook-i18n-helpers]: https://github.com/google/mdbook-i18n-helpers
[mdbook-i18n-helpers USAGE]: https://github.com/google/mdbook-i18n-helpers/blob/main/i18n-helpers
