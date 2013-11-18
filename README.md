vSPD
====

vectorised Scheduling, Pricing and Dispatch - an audited, mathematical replica of SPD.

Input GDX files are available daily from ..\Datasets\Wholesale\Final_pricing\GDX\ at
ftp://ftp.emi.ea.govt.nz

The Electricity Authority wrote vSPD using the GAMS software in 2008. Dr Ramu Naidoo
was the original author and custodian of vSPD until Nov 2013. Dr Phil Bishop and Tuong
Nguyen now take care of vSPD. Others at the Electricity Authority also contribute.

Contact: emi@ea.govt.nz


TODO:
- One day, alias the frequently-used sets with short labels
  i_dateTime(*)    as dt,
  i_tradePeriod(*) as tp,
  i_offer(*)       as o,
  i_trader(*)      as trdr,
  i_bid(*)         as bid ???,
  i_node(*)        as n,
  i_bus(*)         as b,
  i_branch(*)      as br,
- blah blah blah

