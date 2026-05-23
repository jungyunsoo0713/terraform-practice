resource "aws_internet_gateway" "this" {
    count = local.enable_igw ? 1 : 0 

    vpc_id = local.vpc_id

    tags = merge(
        local.module_tag,
        {
            Name = "${local.vpc_name}-igw",
        }
    )
}

resource "aws_route" "public_igw" {
    count = local.enable_igw ? 1 : 0

    destination_cidr_block = "0.0.0.0/0"
    # count.index를 쓰면 count = 0일 때는 아예 route가 안 만들어지고, 
    # count = 1일 때는 [0]을 참조합니다 
    route_table_id = aws_route_table.public[count.index].id
    gateway_id = aws_internet_gateway.this[count.index].id
}