# Jar's Mouse Action Bar    

Simple cursor-attached action bar for WoW. 

![jmab](https://github.com/user-attachments/assets/494080fb-e157-4d79-a6fc-3d95da2e6862)

This is another hyper-specific addon and a pet project of mine. 

I used to use a mouse-attached cooldown and ability notification weakaura I would use across my healing class. This kind of replaces that. 

Unfortauntely, I cannot use BuffIDs or SpellIDs to filter / check for things like enhancement buffs or stack counts on the icons. But, I was able to attach the Action Bar icon feed which includes most of the synergestic information that I care about when I heal. 

## Configuarion

`/jmab` Will being up the configuration interface. 

<img width="650" height="592" alt="image" src="https://github.com/user-attachments/assets/fa9dd0da-12d9-4e68-bf33-52e5165fbdad" />

The icon array grid is 5x2. You simply enter the action button number you want reflected in the desired icon slot. 

WoW Midnight has refactored how action bars work... kind of. So I included a `/jmab scan` command that will list out which ability is set for which action bar. You can use this list to nail down which action button is the desired ability. 


