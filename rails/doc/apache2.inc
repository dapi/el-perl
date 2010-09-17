
# Auto include
<Location /${SYSTEM}/>
  SetHandler perl-script
  PerlResponseHandler  ${SYSTEM}->handler
</Location>