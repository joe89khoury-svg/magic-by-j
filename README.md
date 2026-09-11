# Magic by J

One page product site with a backoffice for editing content.

## Files

| File | What it is |
|---|---|
| `index.html` | The website visitors see |
| `admin.html` | Your backoffice, for editing everything |
| `content.json` | All text, prices, and image paths live here |
| `assets/` | Your images and logo |
| `supabase-setup.sql` | Run once to enable live counter, orders, and WhatsApp alerts |

The website reads everything from `content.json`. Nothing is hard coded, so you never need to touch the HTML.

## Going live on GitHub Pages

1. Create a free account at github.com.
2. Click **New repository**. Name it `magic-by-j`, set it to **Public**, and create it.
3. On the repository page click **Add file, Upload files**.
4. Drag in `index.html`, `admin.html`, `content.json`, `README.md`, `supabase-setup.sql`, and the whole `assets` folder.
5. Click **Commit changes**.
6. Go to **Settings, Pages**. Under Source pick **Deploy from a branch**, choose branch `main` and folder `/ (root)`. Save.
7. Wait about a minute. Your site is live at `https://YOURNAME.github.io/magic-by-j/`

### Connecting your domain

1. Buy your domain (spaceship.com is the cheapest option).
2. In GitHub, go to **Settings, Pages, Custom domain**, type your domain, and save.
3. At your registrar, open DNS settings and add these records:

   | Type | Name | Value |
   |---|---|---|
   | A | @ | 185.199.108.153 |
   | A | @ | 185.199.109.153 |
   | A | @ | 185.199.110.153 |
   | A | @ | 185.199.111.153 |
   | CNAME | www | YOURNAME.github.io |

4. Back in GitHub Pages, tick **Enforce HTTPS** once it becomes available.

DNS can take a few hours to take effect.

## Using the backoffice

Open `https://yourdomain.com/admin.html`

You can change every text, swap any image, change the price, and start or stop a promotion.

To publish a change:

1. Make your edits.
2. Click **Preview site** to check it.
3. Click **Download content.json**.
4. On GitHub, click **Add file, Upload files**, drag in the new `content.json`, and commit.
5. Refresh your site after about a minute.

### Changing an image

1. In the backoffice, drop in the new image to see how it looks.
2. Upload that same image file into the `assets` folder on GitHub.
3. Back in the backoffice, type the path, for example `assets/my-new-photo.webp`.
4. Download `content.json` and upload it.

Keep images under about 300 KB so the site stays fast. Use squoosh.app to compress.

### Running a new promotion

Go to **Pricing**, set the regular price and the promotion price, write your badge text, set how many are in the batch, and make sure **Promotion is running** is ticked. Turn the tick off and the site simply shows the regular price with no counter.

## Receiving orders and the live counter

Both of these run on a free Supabase project. Set it up once and you get:

- a **real shared counter** that every visitor sees, going down as orders come in
- every order **saved in a database** you can export
- a **WhatsApp message to your phone** the moment an order is placed

### Setup, about fifteen minutes

1. Create a free account at **supabase.com** and start a new project. Choose a region near Lebanon, such as Frankfurt. Save the database password somewhere safe.
2. Open the **SQL Editor**, paste in the whole of `supabase-setup.sql`, and press **Run**.
3. Get your WhatsApp key. Add **+34 644 51 95 23** to your contacts, then send it this message on WhatsApp:

   `I allow callmebot to send me messages`

   It replies with your personal API key.
4. Back in the SQL Editor, scroll to the last block of `supabase-setup.sql`. Put in your phone number, the API key from step 3, and a passphrase you choose. Run just that block.
5. Go to **Project Settings, API**. Copy the **Project URL** and the **anon public** key.
6. In the backoffice, open the **Connections** tab, paste both in, and press **Test connection**.
7. Download `content.json` and upload it to GitHub.

Orders now arrive on your WhatsApp, and the counter is shared by everyone.

### Managing the counter once it is live

Open the backoffice, go to **Pricing**. When a database is connected you get a **Live counter** panel showing the real number. Change the total or the remaining, enter your passphrase, and press **Update live counter**. It applies instantly, with no upload needed.

To start a fresh promotion: set the batch total and remaining to the new number, tick **Promotion is running**, and update. To end one, untick it.

### Seeing your orders

In Supabase, open **Table Editor** and pick the `orders` table. Every order is there with a timestamp. The **Export to CSV** button gives you a spreadsheet.

### Notes on the setup

- The **anon key is meant to be public.** Your tables are locked with row level security, so nobody can read your orders or edit the counter with it. Orders and counter changes only happen through the two protected functions.
- The **admin passphrase is basic protection.** It stops casual tampering with your counter. Choose something long, and do not reuse a password you use elsewhere.
- **CallMeBot is a free service** run by one developer, so treat WhatsApp alerts as a convenience rather than something to depend on. Your orders are always safe in the database regardless. If you later want something more robust, Twilio's WhatsApp API is the paid alternative.
- The free Supabase tier pauses a project after a week with no activity. A live site with visitors keeps it awake, but if you go quiet for a while, open the dashboard once to wake it.

## Two things to know

**The backoffice is not password protected.** Anyone who knows the address can open it and see your settings. They cannot change your live site without your GitHub account, and they cannot change the counter without the passphrase. If you would rather keep it private, do not upload `admin.html`, and run it from your own computer instead.

**Without the Supabase setup**, the site still works: the form validates and confirms, and the counter goes down for that one visitor only. Nothing is recorded anywhere. Do the setup above before you start selling.
