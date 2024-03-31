
# FROM public.ecr.aws/lambda/python@sha256:e1948dc355b1d65f11ffe48d15c46b4e4aad0ea77851b63914f67bcaa678567f as build
FROM public.ecr.aws/compose-x/python:3.9.20220504-amd64 AS build

RUN yum install -y unzip && \
    curl -Lo "/tmp/chromedriver.zip" "https://chromedriver.storage.googleapis.com/109.0.5414.74/chromedriver_linux64.zip" && \
    curl -Lo "/tmp/chrome-linux.zip" "https://www.googleapis.com/download/storage/v1/b/chromium-browser-snapshots/o/Linux_x64%2F1070081%2Fchrome-linux.zip?alt=media" && \
    unzip /tmp/chromedriver.zip -d /opt/ && \
    unzip /tmp/chrome-linux.zip -d /opt/

# FROM public.ecr.aws/lambda/python@sha256:e1948dc355b1d65f11ffe48d15c46b4e4aad0ea77851b63914f67bcaa678567f
FROM public.ecr.aws/compose-x/python:3.9.20220504-amd64
RUN yum install atk cups-libs gtk3 libXcomposite alsa-lib \
    libXcursor libXdamage libXext libXi libXrandr libXScrnSaver \
    libXtst pango at-spi2-atk libXt xorg-x11-server-Xvfb \
    xorg-x11-xauth dbus-glib dbus-glib-devel -y

COPY prod.env .env

# update pip and install libs
COPY requirements.txt requirements.txt
RUN pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir -r ./requirements.txt

COPY --from=build /opt/chrome-linux /opt/chrome
COPY --from=build /opt/chromedriver /opt/

# copy function code to container
COPY main.py main.py

# set display port to avoid crash
ENV DISPLAY=:99

ENTRYPOINT ["python"]
CMD ["main.py"]