FROM mysql:5.7

COPY load-data.sh /scripts/load-data.sh
RUN chmod +x /scripts/load-data.sh

ENTRYPOINT ["sh", "/scripts/load-data.sh"]
