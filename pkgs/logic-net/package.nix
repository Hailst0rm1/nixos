{
  lib,
  buildDotnetModule,
  dotnetCorePackages,
  fetchFromGitHub,
  mono,
  makeWrapper,
}:
buildDotnetModule rec {
  pname = "logic-net";
  version = "0-unstable-2023-02-07";

  src = fetchFromGitHub {
    owner = "SygniaLabs";
    repo = "LoGiC.NET";
    rev = "48808597b58efd7481c81efbb622d29c880182f6";
    hash = "sha256-CTKvinNgFwlh5VXCT6SII7fP4pAFaGT0uw+AAPGzzoI=";
  };

  # Convert legacy .csproj to SDK-style so dotnet CLI can build it
  # SharpConfigParser.dll is a pre-built binary bundled in the repo
  postUnpack = ''
    cat > "$sourceRoot/LoGiC.NET.csproj" << 'CSPROJ'
    <Project Sdk="Microsoft.NET.Sdk">
      <PropertyGroup>
        <OutputType>Exe</OutputType>
        <TargetFramework>net472</TargetFramework>
        <AssemblyName>LoGiC.NET</AssemblyName>
        <RootNamespace>LoGiC.NET</RootNamespace>
        <GenerateAssemblyInfo>false</GenerateAssemblyInfo>
        <AllowUnsafeBlocks>true</AllowUnsafeBlocks>
      </PropertyGroup>
      <ItemGroup>
        <PackageReference Include="dnlib" Version="3.3.3" />
      </ItemGroup>
      <ItemGroup>
        <Reference Include="SharpConfigParser">
          <HintPath>SharpConfigParser.dll</HintPath>
        </Reference>
      </ItemGroup>
    </Project>
    CSPROJ
  '';

  projectFile = "LoGiC.NET.csproj";
  nugetDeps = ./deps.json;

  dotnet-sdk = dotnetCorePackages.sdk_8_0;

  executables = [];
  packNupkg = false;

  nativeBuildInputs = [makeWrapper];

  installPhase = ''
    runHook preInstall

    local buildDir="bin/Release/net472/linux-x64"
    local libDir="$out/lib/${pname}"

    mkdir -p "$libDir" "$out/bin"
    cp -r "$buildDir"/* "$libDir"/

    makeWrapper ${mono}/bin/mono "$out/bin/logic-net" \
      --add-flags "$libDir/LoGiC.NET.exe"

    runHook postInstall
  '';

  meta = with lib; {
    description = ".NET obfuscator using dnlib with renaming, encryption, and control flow protection";
    homepage = "https://github.com/SygniaLabs/LoGiC.NET";
    license = licenses.mit;
    platforms = platforms.linux;
    mainProgram = "logic-net";
  };
}
