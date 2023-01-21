FROM ubuntu:20.04

RUN apt-get update && \
    apt-get install -y wine64-development python3 msitools python3-simplejson \
                       python3-six ca-certificates && \
    apt-get clean -y && \
    rm -rf /var/lib/apt/lists/*


################## DOTNET ####################

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        ca-certificates \
        \
        # .NET dependencies
        libc6 \
        libgcc1 \
        libgssapi-krb5-2 \
#        libicu70 \
#        libssl3 \
        libstdc++6 \
        zlib1g

RUN apt-get install -y --no-install-recommends \
        curl \
        git \
        wget \
        p7zip-full p7zip-rar \
    && rm -rf /var/lib/apt/lists/*

ENV \
    # Enable detection of running in a container
    DOTNET_RUNNING_IN_CONTAINER=true

WORKDIR /usr/share/dotnet

# Retrieve .NET Runtime
RUN dotnet_version=7.0.2 \
    && curl -fSL --output dotnet.tar.gz https://dotnetcli.azureedge.net/dotnet/Runtime/$dotnet_version/dotnet-runtime-$dotnet_version-linux-x64.tar.gz \
    && dotnet_sha512='56f7f471052b955968b9a4caa27299ac003e0347ae80e8ef23de87d28a2707bdf7ceb70467cc3e9f0c80928a779841dd7e1392ed6b06e66a7a9cda696d5c0a1e' \
    && echo "$dotnet_sha512  dotnet.tar.gz" | sha512sum -c - \
    && mkdir -p /usr/share/dotnet \
    && tar -oxzf dotnet.tar.gz -C /usr/share/dotnet \
    && rm dotnet.tar.gz

RUN ln -s /usr/share/dotnet/dotnet /usr/bin/dotnet

ENV \
    # Unset ASPNETCORE_URLS from aspnet base image
    ASPNETCORE_URLS= \
    # Do not generate certificate
    DOTNET_GENERATE_ASPNET_CERTIFICATE=false \
    # Do not show first run text
    DOTNET_NOLOGO=true \
    # SDK version
    DOTNET_SDK_VERSION=7.0.102 \
    # Enable correct mode for dotnet watch (only mode supported in a container)
    DOTNET_USE_POLLING_FILE_WATCHER=true \
    # Skip extraction of XML docs - generally not useful within an image/container - helps performance
    NUGET_XMLDOC_MODE=skip \
    # PowerShell telemetry for docker image usage
    POWERSHELL_DISTRIBUTION_CHANNEL=PSDocker-DotnetSDK-Ubuntu-22.04

# Install .NET SDK
RUN curl -fSL --output dotnet.tar.gz https://dotnetcli.azureedge.net/dotnet/Sdk/$DOTNET_SDK_VERSION/dotnet-sdk-$DOTNET_SDK_VERSION-linux-x64.tar.gz \
    && dotnet_sha512='7667aae20a9e50d31d1fc004cdc5cb033d2682d3aa793dde28fa2869de5ac9114e8215a87447eb734e87073cfe9496c1c9b940133567f12b3a7dea31a813967f' \
    && echo "$dotnet_sha512  dotnet.tar.gz" | sha512sum -c - \
    && mkdir -p /usr/share/dotnet \
    && tar -oxzf dotnet.tar.gz -C /usr/share/dotnet ./packs ./sdk ./sdk-manifests ./templates ./LICENSE.txt ./ThirdPartyNotices.txt \
    && rm dotnet.tar.gz \
    # Trigger first run experience by running arbitrary cmd
    && ls -lah && ls -lah /usr/share/dotnet && dotnet help

# Install PowerShell global tool
#RUN powershell_version=7.2.7 \
#    && curl -fSL --output PowerShell.Linux.x64.$powershell_version.nupkg https://pwshtool.blob.core.windows.net/tool/$powershell_version/PowerShell.Linux.x64.$powershell_version.nupkg \
#    && powershell_sha512='465db0b02507d8c055a0ef9ae4e43395a9897b632660a0d1c07788159d13b9cc54d44823123ea001bbe3ad97740b0e5f998cb3378c84ba8824bc233559f32288' \
#    && echo "$powershell_sha512  PowerShell.Linux.x64.$powershell_version.nupkg" | sha512sum -c - \
#    && mkdir -p /usr/share/powershell \
#    && dotnet tool install --add-source / --tool-path /usr/share/powershell --version $powershell_version PowerShell.Linux.x64 \
#    && dotnet nuget locals all --clear \
#    && rm PowerShell.Linux.x64.$powershell_version.nupkg \
#    && ln -s /usr/share/powershell/pwsh /usr/bin/pwsh \
#    && chmod 755 /usr/share/powershell/pwsh \
#    # To reduce image size, remove the copy nupkg that nuget keeps.
#    && find /usr/share/powershell -print | grep -i '.*[.]nupkg$' | xargs rm

##############################################



WORKDIR /opt/msvc

COPY lowercase fixinclude install.sh vsdownload.py ./
COPY wrappers/* ./wrappers/

RUN PYTHONUNBUFFERED=1 ./vsdownload.py --accept-license --dest /opt/msvc && \
    ./install.sh /opt/msvc && \
    rm lowercase fixinclude install.sh vsdownload.py && \
    rm -rf wrappers

COPY msvcenv-native.sh /opt/msvc

# Initialize the wine environment. Wait until the wineserver process has
# exited before closing the session, to avoid corrupting the wine prefix.
RUN wine64 wineboot --init && \
    while pgrep wineserver > /dev/null; do sleep 1; done

# Later stages which actually uses MSVC can ideally start a persistent
# wine server like this:
#RUN wineserver -p && \
#    wine64 wineboot && \
