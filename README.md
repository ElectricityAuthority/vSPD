vSPD (RTP4 v4.1.0 development)
====

vectorised Scheduling, Pricing and Dispatch - an audited, mathematical replica of SPD, the
pricing and dispatch engine used in the New Zealand electricity market.

[Input GDX files are published daily on EMI](https://www.emi.ea.govt.nz/Wholesale/Datasets/DispatchAndPricing/GDX/) or 
can be obtained directly from the underlying Azure storage account (see [instructions](https://www.emi.ea.govt.nz/Forum/thread/new-access-arrangements-to-emi-datasets-retirement-of-anonymous-ftp/) 
on the EMI forum).

The Electricity Authority created vSPD using the GAMS software in 2008. Dr Ramu Naidoo was
the original author and, until November 2013, the custodian of vSPD. Tuong Nguyen and Phil Bishop
from the Data and Information Management team now maintain the vSPD model.

vSPD was most recently audited in August 2019 - see the audited vSPD codes and the auditor's certification on the [EMI vSPD page](https://www.emi.ea.govt.nz/Wholesale/Tools/vSPD).

Throughout 2022, vSPD was extensively modified to accomodate the 1 November 2022 go-live of real-time pricing. Backward 
compatability with GDX files was broken with this change.

Version 3.1.0, available on the [EMI vSPD page,](https://www.emi.ea.govt.nz/Wholesale/Tools/vSPD) is
the last version of vSPD to work with [GDX files](https://www.emi.ea.govt.nz/Wholesale/Datasets/DispatchAndPricing/Pre1November2022Archive/GDX/) pertaining to all days up to and 
including 31 October 2022.

Version 4.0.0, also available on the [EMI vSPD page,](https://www.emi.ea.govt.nz/Wholesale/Tools/vSPD) is
the first version of vSPD to work with [GDX files](https://www.emi.ea.govt.nz/Wholesale/Datasets/DispatchAndPricing/GDX/) pertaining to all days since 
1 November 2022.

Both versions, v3.1.0 and v4.0.0, are also available from the [releases page](https://github.com/ElectricityAuthority/vSPD/releases) of this GitHub repository.

Contact: emi@ea.govt.nz
