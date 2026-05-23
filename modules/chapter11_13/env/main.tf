locals {
  info_files = "${path.root}/../info_files" # path.root는 main.tf를 실행하는 디렉터리를 의미합니다. 

  vpc_set = toset([
    for vpcfile in fileset(local.info_files, "*/vpc.yaml") : dirname(vpcfile)
  ])
}

# fileset은 특정 디렉터리안에서 조건에 맞는 파일 목록을 보여줍니다. 
# *는 local.info_files 바로 아래의 폴더 하나를 의미합니다.
# > fileset(local.info_files, "*/vpc.yaml")
# toset([
#     "vpc-1/vpc.yaml"
#     "vpc-2/vpc.yaml"
# ])
