# Use this base image so everything comes from RPM packages (including OSC plugins)
ARG BUILDER_IMAGE=registry.access.redhat.com/ubi10/ubi-minimal:latest
ARG BASE_IMAGE=registry.access.redhat.com/ubi10/ubi-minimal:latest
ARG S2I_FOLDER=./.s2i

FROM $BUILDER_IMAGE AS builder
ARG S2I_FOLDER
ARG TARGETARCH=amd64

COPY . /app
WORKDIR /app

COPY ${S2I_FOLDER}/builddeps.txt /tmp/builddeps.txt
RUN pkgs=$(cat /tmp/builddeps.txt | grep -v '^#' | grep -v '^$' | tr '\n' ' ') && \
    if [ -n "${pkgs}" ]; then microdnf -y install ${pkgs}; microdnf clean all; fi

COPY ${S2I_FOLDER}/requirements.lock /tmp/requirements.lock
RUN pip3 wheel -r /tmp/requirements.lock --wheel-dir ./wheels && \
    pip3 wheel --no-deps . --wheel-dir ./wheels

COPY openshift-client-linux-${TARGETARCH}.tar.gz oc.tar.gz
RUN tar xvf oc.tar.gz oc && \
    chmod +x oc && \
    rm oc.tar.gz

FROM $BASE_IMAGE
ARG S2I_FOLDER
LABEL com.redhat.component="rhos-ls-mcps" \
      name="openstack-lightspeed/rhos-mcps" \
      summary="MCP server providing OpenStack tools for RHOS-Lightspeed" \
      io.k8s.name="rhos-mcps" \
      io.k8s.description="MCP Tools for RHOS-Lightspeed" \
      io.openshift.tags="openstack,lightspeed,mcp" \
      org.label-schema.vcs-url="https://github.com/openstack-k8s-operators/lightspeed-mcps"

WORKDIR /app

COPY --from=builder /app/wheels /app/wheels
COPY --from=builder /app/oc /usr/local/bin

COPY ${S2I_FOLDER}/bindeps.txt /tmp/bindeps.txt
RUN pkgs=$(cat /tmp/bindeps.txt | grep -v '^#' | grep -v '^$' | tr '\n' ' ') && \
    if [ -n "${pkgs}" ]; then microdnf -y install ${pkgs} && microdnf clean all && rm -rf /var/cache/dnf; fi && \
    rm /tmp/bindeps.txt

RUN pip3 install --no-cache-dir --prefix=/usr /app/wheels/*.whl && \
    rm -rf /app/wheels

EXPOSE 8080
USER 1001

ENTRYPOINT ["rhos-ls-mcps", "--ip", "0.0.0.0"]
