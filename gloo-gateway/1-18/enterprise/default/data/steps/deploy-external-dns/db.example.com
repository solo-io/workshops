; base zone file for example.com.
$TTL 60s    ; default TTL for zone (in seconds)
$ORIGIN example.com. ; base domain-name

; Start of Authority RR defining the key characteristics of the zone (domain)
@       IN      SOA     ns1.example.com. hostmaster.example.com. (
                                2003080800 ; serial number
                                12h        ; refresh
                                15m        ; update retry
                                3w         ; expiry
                                2h         ; minimum
                                )
; name server RR for the domain
        IN      NS      ns1.example.com.

; this record is needed for the zone to load into bind
ns1     IN      A       127.0.0.1


