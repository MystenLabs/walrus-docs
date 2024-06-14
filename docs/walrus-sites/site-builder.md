# The site builder

To facilitate the creation of Walrus Sites, we provide the "site builder" tool. The site builder
takes care of creating Walrus Sites object on Sui, with the correct structure, and stores the site
resources to Walrus.

## Site builder commands

The site builder tool exposes the following commands:

- `publish`: Allows to publish a specific directory to Walrus. The directory must contain files that
  can be served with HTTP, and have an `index.html` file. This command will return a Sui object ID
  for the newly created site.
- `update`: After creating a site, you can update it with this command. It takes as input a
  directory, as above, with the new or updated files, and the object ID of the site to update. Note
  that the wallet you are using must be the _owner_ of the Walrus Site object to be able to update
  it. This command will remove and create resources as required, to ensure that the Walrus Sites
  object on Sui matches the local directory. If run with `--watch`, this command re-updates the site
  _every time a file in the directory changes_. This is useful during development, but pay attention
  to costs!
- `convert`: A utility tool. Given a Sui object ID in Hex format, it converts it to Base36. This is
  useful if you know the Sui object ID of a site, and want to find the URL.
- `sitemap`: A utility tool. For a give Walrus Sites Sui object ID, prints out all the resources
  that compose the site and their object ID.

Check the commands' `--help` for more information.
