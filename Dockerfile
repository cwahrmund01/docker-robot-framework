FROM fedora:40

LABEL authors     Paul Podgorsek
LABEL description Robot Framework in Docker.

# Set the Python dependencies' directory environment variable
ENV ROBOT_DEPENDENCY_DIR /opt/robotframework/dependencies

# Set the reports directory environment variable
ENV ROBOT_REPORTS_DIR /opt/robotframework/reports

# Set the tests directory environment variable
ENV ROBOT_TESTS_DIR /opt/robotframework/tests

# Set the working directory environment variable
ENV ROBOT_WORK_DIR /opt/robotframework/temp

# Setup X Window Virtual Framebuffer
ENV SCREEN_COLOUR_DEPTH 24
ENV SCREEN_HEIGHT 1080
ENV SCREEN_WIDTH 1920

# Setup the timezone to use, defaults to UTC
ENV TZ UTC

# Set number of threads for parallel execution
# By default, no parallelisation
ENV ROBOT_THREADS 1

# Define the default user who'll run the tests
ENV ROBOT_UID 1000
ENV ROBOT_GID 1000

# Dependency versions
ENV AXE_SELENIUM_LIBRARY_VERSION 2.1.6
ENV BROWSER_LIBRARY_VERSION 18.8.1
ENV CHROME_VERSION 129.0.6668.100
ENV DATABASE_LIBRARY_VERSION 2.0.2
ENV DATADRIVER_VERSION 1.11.2
ENV DATETIMETZ_VERSION 1.0.6
ENV FAKER_VERSION 5.0.0
ENV FIREFOX_VERSION 131.0
ENV FTP_LIBRARY_VERSION 1.9
ENV GECKO_DRIVER_VERSION v0.35.0
ENV IMAP_LIBRARY_VERSION 0.4.10
ENV PABOT_VERSION 2.18.0
ENV REQUESTS_VERSION 0.9.7
ENV ROBOT_FRAMEWORK_VERSION 7.1
ENV SELENIUM_LIBRARY_VERSION 6.6.1
ENV SSH_LIBRARY_VERSION 3.8.0
ENV XVFB_VERSION 1.20

# Prepare binaries to be executed
COPY bin/chromedriver.sh /opt/robotframework/drivers/chromedriver
COPY bin/chrome.sh /opt/robotframework/bin/chrome
COPY bin/run-tests-in-virtual-screen.sh /opt/robotframework/bin/

# Install system dependencies
RUN dnf upgrade -y --refresh \
  && dnf install -y \
    dbus-glib \
    dnf-plugins-core \
    firefox-${FIREFOX_VERSION}* \
    gcc \
    gcc-c++ \
    nodejs \
    npm \
    python3-pip \
    python3-pyyaml \
    tzdata \
    wget \
    xorg-x11-server-Xvfb-${XVFB_VERSION}* \
  && dnf clean all

# Install Chrome for Testing
# https://developer.chrome.com/blog/chrome-for-testing/
RUN npx @puppeteer/browsers install chrome@${CHROME_VERSION} \
  && npx @puppeteer/browsers install chromedriver@${CHROME_VERSION}

# Install Robot Framework and associated libraries
RUN pip3 install \
  --no-cache-dir \
  robotframework==${ROBOT_FRAMEWORK_VERSION} \
  robotframework-browser==${BROWSER_LIBRARY_VERSION} \
  robotframework-databaselibrary==${DATABASE_LIBRARY_VERSION} \
  robotframework-datadriver==${DATADRIVER_VERSION} \
  robotframework-datadriver[XLS] \
  robotframework-datetime-tz==${DATETIMETZ_VERSION} \
  robotframework-faker==${FAKER_VERSION} \
  robotframework-ftplibrary==${FTP_LIBRARY_VERSION} \
  robotframework-imaplibrary2==${IMAP_LIBRARY_VERSION} \
  robotframework-pabot==${PABOT_VERSION} \
  robotframework-requests==${REQUESTS_VERSION} \
  robotframework-seleniumlibrary==${SELENIUM_LIBRARY_VERSION} \
  robotframework-sshlibrary==${SSH_LIBRARY_VERSION} \
  axe-selenium-python==${AXE_SELENIUM_LIBRARY_VERSION}

# Gecko drivers
# Download Gecko drivers directly from the GitHub repository
RUN wget -q "https://github.com/mozilla/geckodriver/releases/download/$GECKO_DRIVER_VERSION/geckodriver-$GECKO_DRIVER_VERSION-linux64.tar.gz" \
  && tar xzf geckodriver-$GECKO_DRIVER_VERSION-linux64.tar.gz \
  && mkdir -p /opt/robotframework/drivers/ \
  && mv geckodriver /opt/robotframework/drivers/geckodriver \
  && rm geckodriver-$GECKO_DRIVER_VERSION-linux64.tar.gz

RUN dnf clean all

# FIXME: Playright currently doesn't support relying on system browsers, which is why the `--skip-browsers` parameter cannot be used here.
# Additionally, it cannot run fully on any OS due to https://github.com/microsoft/playwright/issues/29559
RUN rfbrowser init chromium firefox

# Create the default report and work folders with the default user to avoid runtime issues
# These folders are writeable by anyone, to ensure the user can be changed on the command line.
RUN mkdir -p ${ROBOT_REPORTS_DIR} \
  && mkdir -p ${ROBOT_WORK_DIR} \
  && chown ${ROBOT_UID}:${ROBOT_GID} ${ROBOT_REPORTS_DIR} \
  && chown ${ROBOT_UID}:${ROBOT_GID} ${ROBOT_WORK_DIR} \
  && chmod ugo+w ${ROBOT_REPORTS_DIR} ${ROBOT_WORK_DIR}

# Allow any user to write logs
RUN chmod ugo+w /var/log \
  && chown ${ROBOT_UID}:${ROBOT_GID} /var/log

# Update system path
ENV PATH=/opt/robotframework/bin:/opt/robotframework/drivers:$PATH

# Ensure the directory for Python dependencies exists
RUN mkdir -p ${ROBOT_DEPENDENCY_DIR} \
  && chown ${ROBOT_UID}:${ROBOT_GID} ${ROBOT_DEPENDENCY_DIR} \
  && chmod 777 ${ROBOT_DEPENDENCY_DIR}

# Set up a volume for the generated reports
VOLUME ${ROBOT_REPORTS_DIR}

USER ${ROBOT_UID}:${ROBOT_GID}

# A dedicated work folder to allow for the creation of temporary files
WORKDIR ${ROBOT_WORK_DIR}

# Execute all robot tests
CMD ["run-tests-in-virtual-screen.sh"]
