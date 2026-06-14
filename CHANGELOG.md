# Changelog

All notable changes to this project will be documented in this file.

## [1.7.7](https://github.com/easytocloud/cloudX/compare/v1.7.6...v1.7.7) (2026-06-14)


### Bug Fixes

* remove explicit Name from CloudXSetupDocument to allow in-place updates ([e3e9455](https://github.com/easytocloud/cloudX/commit/e3e94552869f8f2659c04a854bdc90a7c87a8b8d))

## [1.7.6](https://github.com/easytocloud/cloudX/compare/v1.7.5...v1.7.6) (2026-06-14)


### Bug Fixes

* switch AutoUpdateAssociation to cron schedule to prevent launch race ([4a2af37](https://github.com/easytocloud/cloudX/commit/4a2af371b5fe96b57179ce4a780bb04b07c1439e))

## [1.7.5](https://github.com/easytocloud/cloudX/compare/v1.7.4...v1.7.5) (2026-06-14)


### Bug Fixes

* scope ssm:GetParameter to own environment namespace ([1f39fcb](https://github.com/easytocloud/cloudX/commit/1f39fcbd0b33e4143e13659bda3904169d8630b0))

## [1.7.4](https://github.com/easytocloud/cloudX/compare/v1.7.3...v1.7.4) (2026-06-14)


### Bug Fixes

* grant ssm:GetParameter on /cloudX/* to EC2 instance role ([7d73de7](https://github.com/easytocloud/cloudX/commit/7d73de7eb0eb67d555a0fff0c88777eee58798b5))

## [1.7.3](https://github.com/easytocloud/cloudX/compare/v1.7.2...v1.7.3) (2026-06-14)


### Bug Fixes

* remove invalid rate(365 days) schedule from SetupAssociation ([9324c1d](https://github.com/easytocloud/cloudX/commit/9324c1d492f9d9dfbfd1b6c2dbd27894fc1f86cc))


### Documentation

* **claude.md:** correct association schedule descriptions ([3dc6a8f](https://github.com/easytocloud/cloudX/commit/3dc6a8ff117b7181840510de4ed800e64b4a6e5b))

## [1.7.2](https://github.com/easytocloud/cloudX/compare/v1.7.1...v1.7.2) (2026-06-14)


### Bug Fixes

* set ApplyOnlyAtCronInterval false on AutoUpdateAssociation ([743baf7](https://github.com/easytocloud/cloudX/commit/743baf7867f01921a2d50339261b33302d7b6b44))

## [1.7.1](https://github.com/easytocloud/cloudX/compare/v1.7.0...v1.7.1) (2026-06-14)


### Bug Fixes

* increase default volume size from 16 to 80 GB ([1377bf7](https://github.com/easytocloud/cloudX/commit/1377bf7a175bda351a97977a5af00c31eb7d4fe7))


### Documentation

* **readme:** update to reflect SSM State Manager pet model ([43a7fd9](https://github.com/easytocloud/cloudX/commit/43a7fd9c690a9c4e5b9e37a88c38705753a960ca))

## [1.7.0](https://github.com/easytocloud/cloudX/compare/v1.6.6...v1.7.0) (2026-06-14)


### Features

* add NvmVersion parameter, tag-based update schedule, version tracking, and remove pip ([91edbc8](https://github.com/easytocloud/cloudX/commit/91edbc8787d12f85d81e7e0f9f494c60c0d25850))


### Documentation

* **ai-context:** refresh context files to reflect SSM State Manager pet model ([0d9feaf](https://github.com/easytocloud/cloudX/commit/0d9feaf8ba7cbc50b6957be4942aa7aab5edf982))

## [1.6.6](https://github.com/easytocloud/cloudX/compare/v1.6.5...v1.6.6) (2026-05-18)


### Bug Fixes

* use SSM document to cloudX-ify instances ([a4f08e1](https://github.com/easytocloud/cloudX/commit/a4f08e10fba4c8d2e5d831038b0524fe50948b98))

## [1.6.5](https://github.com/easytocloud/cloudX/compare/v1.6.4...v1.6.5) (2026-05-13)


### Bug Fixes

* update default instance type ([ef9e4a7](https://github.com/easytocloud/cloudX/commit/ef9e4a703408de4c83610db8ff579dbd0b4412d1))

## [1.6.4](https://github.com/easytocloud/cloudX/compare/v1.6.3...v1.6.4) (2026-04-12)


### Bug Fixes

* removed smallest instance models ([0e976f5](https://github.com/easytocloud/cloudX/commit/0e976f5d59fb7370dbad523ef2b5076fb8338290))

## [1.6.3](https://github.com/easytocloud/cloudX/compare/v1.6.2...v1.6.3) (2026-04-12)


### Bug Fixes

* removed smallest instance models ([238efe8](https://github.com/easytocloud/cloudX/commit/238efe883ce1a3fe038878221f495aa6187db862))

## [1.6.2](https://github.com/easytocloud/cloudX/compare/v1.6.1...v1.6.2) (2026-03-29)


### Bug Fixes

* use PATH-resolved aws_completer instead of absolute path ([c35a76f](https://github.com/easytocloud/cloudX/commit/c35a76f7f5671473829467873106e2d7aab5b9c5))

## [1.6.1](https://github.com/easytocloud/cloudX/compare/v1.6.0...v1.6.1) (2026-03-24)


### Bug Fixes

* escape \${HOME} in !Sub block to prevent CloudFormation substitution error ([ff5d799](https://github.com/easytocloud/cloudX/commit/ff5d7999cc153277da0d64ec5da7ed5d06d16fc6))

## [1.6.0](https://github.com/easytocloud/cloudX/compare/v1.5.7...v1.6.0) (2026-03-24)


### Features

* introduce add-to-rc for upsert-safe shell rc management ([213f55a](https://github.com/easytocloud/cloudX/commit/213f55ad71e769f50e84b68fc9070756ce0a4b66))

## [1.5.7](https://github.com/easytocloud/cloudX/compare/v1.5.6...v1.5.7) (2026-01-24)


### Bug Fixes

* added ssh hostname field for use with cloudX-proxy ([64c180e](https://github.com/easytocloud/cloudX/commit/64c180ea55aed13817ecc30dedb33f98aa4ea494))

## [1.5.6](https://github.com/easytocloud/cloudX/compare/v1.5.5...v1.5.6) (2026-01-23)


### Bug Fixes

* repair nvm installation ([08a4007](https://github.com/easytocloud/cloudX/commit/08a40076e64dd914be606b305dd8f753523f8880))

## [1.5.5](https://github.com/easytocloud/cloudX/compare/v1.5.4...v1.5.5) (2026-01-23)


### Bug Fixes

* improved installer for oh-my-easytocloud ([e25c40a](https://github.com/easytocloud/cloudX/commit/e25c40ab1d3a302b57b24177d3fce2f440838562))

## [1.5.4](https://github.com/easytocloud/cloudX/compare/v1.5.3...v1.5.4) (2026-01-22)


### Bug Fixes

* improved oh-my-zsh installation ([59e769a](https://github.com/easytocloud/cloudX/commit/59e769aac4a84f6625e56032f791d1bab2d8e5c2))
* improved oh-my-zsh installation ([5bc97eb](https://github.com/easytocloud/cloudX/commit/5bc97ebfae5bd07a75c8de339cce216050c1c714))

## [1.5.3](https://github.com/easytocloud/cloudX/compare/v1.5.2...v1.5.3) (2026-01-14)


### Bug Fixes

* moved ruby from base to additional packages ([092aaec](https://github.com/easytocloud/cloudX/commit/092aaece1d5c7179ac05bd6afe3c51880b9e7686))

## [1.5.2](https://github.com/easytocloud/cloudX/compare/v1.5.1...v1.5.2) (2026-01-14)


### Bug Fixes

* removed gem installation as it is now part of ruby package ([327cde8](https://github.com/easytocloud/cloudX/commit/327cde8198a7e042f3a056392e58a1df1a62f2ea))

## [1.5.1](https://github.com/easytocloud/cloudX/compare/v1.5.0...v1.5.1) (2026-01-14)


### Bug Fixes

* remove unavailable package ruby-devel ([c01fa4d](https://github.com/easytocloud/cloudX/commit/c01fa4de340c6860711a358201eb88f79bb0d8b3))

## [1.5.0](https://github.com/easytocloud/cloudX/compare/v1.4.1...v1.5.0) (2026-01-14)


### Features

* add ruby, gem and yq to base packages ([cb3388d](https://github.com/easytocloud/cloudX/commit/cb3388d9a7608a94c057207a03e1941758618e9c))

## [1.4.1](https://github.com/easytocloud/cloudX/compare/v1.4.0...v1.4.1) (2026-01-12)


### Bug Fixes

* usermod full path in docker install ([083b2d3](https://github.com/easytocloud/cloudX/commit/083b2d33d9cdc62486955e0aa2deb1dfe3462aa4))

## [1.4.0](https://github.com/easytocloud/cloudX/compare/v1.3.6...v1.4.0) (2025-12-02)


### Features

* added arm64 supported instance types ([2e760dd](https://github.com/easytocloud/cloudX/commit/2e760dd1fa387244d48c7f0e7f20eff045a89382))

## [1.3.6](https://github.com/easytocloud/cloudX/compare/v1.3.5...v1.3.6) (2025-12-01)


### Bug Fixes

* added default profile in generated .aws/config ([316bc0f](https://github.com/easytocloud/cloudX/commit/316bc0ff83afdb9d1eb808d94d80b1088dd6f917))

## [1.3.5](https://github.com/easytocloud/cloudX/compare/v1.3.4...v1.3.5) (2025-11-21)


### Documentation

* **ai:** update architecture and project overview for accuracy ([dfebe6a](https://github.com/easytocloud/cloudX/commit/dfebe6a7f232e69ca1d1641d168a894fb69e4949))

## [1.3.4](https://github.com/easytocloud/cloudX/compare/v1.3.3...v1.3.4) (2025-11-21)


### Documentation

* **ai:** add commit message conventions for semantic release ([a1330e7](https://github.com/easytocloud/cloudX/commit/a1330e7a2ad52e43f4f7c03139722ed11f038f50))

## [1.3.3](https://github.com/easytocloud/cloudX/compare/v1.3.2...v1.3.3) (2025-11-21)


### Bug Fixes

* trigger release for repository restructuring ([345ecb8](https://github.com/easytocloud/cloudX/commit/345ecb84f01f7be5c123d65c2f69b32a20f3cfb2))

## [1.3.2](https://github.com/easytocloud/cloudX/compare/v1.3.1...v1.3.2) (2025-11-18)


### Bug Fixes

* allow all outbound traffic from cloudX instance ([5ee40b3](https://github.com/easytocloud/cloudX/commit/5ee40b30640bc93cb227b7c98a4c39cd69b692d7))

## [1.3.1](https://github.com/easytocloud/cloudX/compare/v1.3.0...v1.3.1) (2025-11-17)


### Documentation

* added customization markers ([c3b77fa](https://github.com/easytocloud/cloudX/commit/c3b77fad0aa737639ab3c92a05d517dadafa9692))

## [1.3.0](https://github.com/easytocloud/cloudX/compare/v1.2.0...v1.3.0) (2025-11-17)


### Features

* added customization markers ([61d2a23](https://github.com/easytocloud/cloudX/commit/61d2a23bee01d6f9380e3057582fd4c82d17bac3))

## [1.2.0](https://github.com/easytocloud/cloudX/compare/v1.1.7...v1.2.0) (2025-11-17)


### Features

* added codeartifact config setting ([f10e608](https://github.com/easytocloud/cloudX/commit/f10e608422f690c814ce21181ee7611fa395c01b))

## [1.1.7](https://github.com/easytocloud/cloudX/compare/v1.1.6...v1.1.7) (2025-11-15)


### Bug Fixes

* rewrite instance.yaml using metadata ([a377c57](https://github.com/easytocloud/cloudX/commit/a377c579ad6b32a598a7be48f8d970dc0b5b9fda))

## [1.1.6](https://github.com/easytocloud/cloudX/compare/v1.1.5...v1.1.6) (2025-11-15)


### Bug Fixes

* rewrite instance.yaml using metadata ([0b7337e](https://github.com/easytocloud/cloudX/commit/0b7337e3690e3cf7a4c2f77aaa5d53a1c873138c))

## [1.1.5](https://github.com/easytocloud/cloudX/compare/v1.1.4...v1.1.5) (2025-11-15)


### Bug Fixes

* rewrite instance.yaml using metadata ([34ba98c](https://github.com/easytocloud/cloudX/commit/34ba98ccae11eb747056f141eda82127f8dcfda9))

## [1.1.4](https://github.com/easytocloud/cloudX/compare/v1.1.3...v1.1.4) (2025-11-14)


### Bug Fixes

* syntax zshrc update ([1336f72](https://github.com/easytocloud/cloudX/commit/1336f728bc31e3b32ccb32b7dd064144a8b9525c))

## [1.1.3](https://github.com/easytocloud/cloudX/compare/v1.1.2...v1.1.3) (2025-11-14)


### Bug Fixes

* syntaxt error in generated script ([ee7b590](https://github.com/easytocloud/cloudX/commit/ee7b5901f37724d7badf0aebb7fcc46a1f0786e6))

## [1.1.2](https://github.com/easytocloud/cloudX/compare/v1.1.1...v1.1.2) (2025-11-14)


### Bug Fixes

* launch button updated ([73cd5d5](https://github.com/easytocloud/cloudX/commit/73cd5d5dc9058b9e8fff19990f3362063654bc1b))

## [1.1.1](https://github.com/easytocloud/cloudX/compare/v1.1.0...v1.1.1) (2025-11-14)


### Bug Fixes

* improve ec2cloudx.sh and use it in instance ([15b5912](https://github.com/easytocloud/cloudX/commit/15b59121d88de84fd88b7b16bdeb246c1c2dc690))

## [1.1.0](https://github.com/easytocloud/cloudX/compare/v1.0.0...v1.1.0) (2025-11-14)


### Features

* multiple environment support ([92685a0](https://github.com/easytocloud/cloudX/commit/92685a0a95a269b375cf073191e00f4fd2fae831))


### Bug Fixes

* workflow repair ([d02b59c](https://github.com/easytocloud/cloudX/commit/d02b59cea9f86b19c362b05dc29c3ce072f8c968))
* workflow repair ([2c642c1](https://github.com/easytocloud/cloudX/commit/2c642c1667d0c6f468b52d21b93176c31c2c25af))
* workflow update ([d2434f0](https://github.com/easytocloud/cloudX/commit/d2434f0ed60fde8d5ba57fb380c6fe16faa24d61))
