FROM flant/shell-operator:latest
COPY hooks /hooks
RUN set -feux \
  && chmod go+rwX /run
