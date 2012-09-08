Sadly the most scripts hosted on scripts.irssi.org are outdated so I decided to host the scripts I am using at this place.

Here is the output of /scriptassist check with (almost) all the scripts in this folder:

The scripts marked with * are modified by me or others, see below for the changes.

     ,--[ScriptAssist]
     | o auth_quakenet_challenge No version information available on network.
    \*| o ascii                   Your version is newer (1.6.3-r1-&gt;1.6.3)
    \*| o banaffects_sd           No version information available on network
     | o cap_sasl                No version information available on network.
     | o chanact                 Your version is newer (master-&gt;0.5.14)
     | o chansort                Up to date. (1.4)
     | o colour_popup            No version information available on network.
    \*| o crapbuster              Your version is newer (2003020801-r1-&gt;2003020801)
    \*| o fixlamer                No header in script.
    \*| o foreach_user_nome       No version information available on network.
    \*| o geoip2                  No version information available on network.
     | o getnick                 No version information available on network.
     | o go2                     No version information available on network.
    \*| o hilightwin              Up to date. (0.02)
     | o history_search          Up to date. (2.0)
     | o hlscroll                No version information available on network.
     | o hueg                    No version information available on network.
     | o intercept               No version information available on network.
    \*| o jpqnmwin                No version information available on network.
     | o kicks                   Up to date. (0.26)
     | o knock                   No version information available on network.
     | o nickcolor               Your version is newer (1.2-&gt;1)
    \*| o nickignore              Your version is newer (0.05-&gt;0.03)
     | o notifyquit              No version information available on network.
    \*| o queryresume             Your version is newer (2003021201-r1-&gt;2003021201)
     | o repeat                  Your version is newer (master-&gt;0.2.0)
     | o rtrim                   No version information available on network.
    \*| o sb_position             No version information available on network.
    \*| o scriptassist            Your version is newer (2003020803-r1-&gt;2003020803)
     | o scrolled_reminder       No version information available on network.
     | o softignore              No version information available on network.
     | o splitlong               Up to date. (0.20)
     | o tab_stop                Your version is newer (2011052400-&gt;2002123102)
     | o tabcompletenick         No header in script.
     | o tf                      No version information available on network.
     | o title                   Your version is newer (3.2b-3.2)
    \*| o trackbar                No header in script.
     | o trigger                 Your version is newer (1.0+-1.0)
     | o tt                      No version information available on network.
    \*| o uberprompt              No version information available on network.
     | o whois0810               No version information available on network.
     | o xlist                   Up to date. (1.00)
     | o youtube                 No version information available on network.
     `--&lt;check&gt;-&gt;

Modified scripts (name: what changed):

ascii:             Don't remember, maybe a bufix.
banaffects_sd:     Added self-defense mechanism and changed formats
                   to match the default theme.
crapbuster:        Bugfix.
fixlamer:          Contains my personal replaces.
foreach_user_nome: This is basically foreach_user.pl with yourself excluded.
geoip2:            Changed encoding to UTF-8, made it only use one line in the whois
                   (format: city-&gt;region-&gt;country) and none if location is unkown.
                   Also changed regexes, only lookup by name if a dot is in the host.
hilightwin:        Use "highlightwin" not "hilightwin".
jpqnmwin:          My modification of jpqwin.pl (does nicks and modes too,
                   removed any settings).
linkchan:          Split the username by a dot to prevent highlighting yourself and others.
nickignore:        Bugfix.
queryresume:       Changed color from red to blue to match nico.theme
                   (looks good on default.theme too ;).
sb_position:       Added new formats, four to choose from (line 108+).
scriptassist:      Fixed perl warnings.
trackbar:          Terminal redraw works (not my work), option to exclude windows added,
                   option to draw a timestamp at the bar start added, option to toggle
                   whether the timestamp respects the style/format of the bar added.
                   Command /scroll to easily scroll to the bar added.
uberprompt:        Removed/disabled add/restore and on/off functionality otherwise it does
                   not work with more than the prompt in the statusbars "prompt" section.
                   Add it manually to the statusbar: uberprompt = { priority = "-1"; };
