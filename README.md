Rails app generated with [lewagon/rails-templates](https://github.com/lewagon/rails-templates), created by the [Le Wagon coding bootcamp](https://www.lewagon.com) team.

## Installation

1. **Install rbenv and ruby-build**

   Follow the [rbenv installation guide](https://github.com/rbenv/rbenv#installation) and add the
   [`ruby-build` plugin](https://github.com/rbenv/ruby-build) to manage Ruby versions.

2. **Install the required Ruby version**

   Use rbenv to install the version specified by the project (for example `3.2.4`):

   ```bash
   rbenv install 3.2.4
   rbenv global 3.2.4
   ```

3. **Install Bundler**

   ```bash
   gem install bundler
   ```

4. **Install project dependencies**

   ```bash
   bundle install
   ```

### System dependencies

This project relies on several system packages:

- [ImageMagick](https://imagemagick.org) for image processing.
- `redis-server` for background jobs and caching.
- Any other dependencies required by the Rails ecosystem such as a database server.

### Example task

To import orders from Chronoflock, run:

```bash
rake chronoflock:import_orders
```
