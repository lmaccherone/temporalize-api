  ## Use cases

  **Ready-made web/mobile multi-tenant backend with easy time-series analytics**

  This storage engine was designed for the Temporalize dashboarding/analytics service which can be used for any kind
  of dashboard. However, its temporal capability differentiates it from other such services. If all you need is log tail analytics
  then there are a number of alternative data stores targeting that use case. This storage engine handles that use case as well as
  if not better than those alternatives, but it goes way beyond and is arguably the fastest, most flexible, and easiest way to
  trend metrics or perform duration/cycle-time analytics. If you ever wished you could say, "How did this report look
  when I ran it three months ago?" then Temporalize is for you.
  
  Temporalize's super fast time-series analytics comes from its exploitation of the property that **the past never changes**.
  Its aggregation capability is optimized to take advantage of this property. Without you doing a thing, Temporalize
  will cache and incrementally update any aggregations that you send to it. It a record of any aggregation spec
  you send to it and then when you ask for the same aggregation again, it only calculates the updates. The default is
  for these to be wiped out if they haven't been requested for 40 days. 

  **As your system's primary data store**

  I personally use it as my primary data store for everything where it captures full history for every entity. "Wasteful",
  you say? Not if you consider that storage is very cheap. The problem is not having enough space, it's not having a
  model that allows you to think of data as immutable. From Datomic, "How can data be immutable? Don't facts change?
  They don't, in fact, when you incorporate time in the data. For instance, when Obama became president, it didn't mean
  that Bush was never president." **This means you only need one data store for both transactions AND analytics**,
  greatly simplifying your system.

  **Web and mobile app development**



  **Agile**

  **Where is Temporalize not a good fit?**

  Like Datomic which shares a lot of concepts, Temporalize is not a good fit if you need unlimited write scalability or
  for values with high churn rate (counters, etc.). That said, Temporalize is horizontally scalable and is commonly used in
  cases where the write:read ratio is 100:1 or higher and with a lot of writes.