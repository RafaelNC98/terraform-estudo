# Projeto Terraform: servidor web com balanceamento e escalabilidade

Este projeto usa Terraform para provisionar na AWS uma aplicação web simples,
servida por instâncias EC2 com Apache. Um Application Load Balancer (ALB)
distribui as requisições entre as instâncias, e um Auto Scaling Group (ASG)
ajusta a capacidade conforme a utilização média de CPU.

## Arquitetura

- Usa a região `us-east-1` e a VPC padrão da conta AWS.
- Cria grupos de segurança para permitir HTTP público no ALB e HTTP nas
  instâncias somente a partir do grupo de segurança do ALB.
- Cria um Launch Template com a AMI configurada em `main.tf`, instâncias
  `t3.micro` e um script de inicialização que instala e inicia o Apache.
- Cria um ALB público, um grupo de destino com verificação de saúde HTTP e um
  listener na porta 80.
- Cria um ASG com capacidade desejada inicial de 2 instâncias, mínimo de 2 e
  máximo de 4. Uma política de rastreamento de alvo mantém a CPU média em 50%.
- Exibe a URL do ALB e os IPs públicos das instâncias em execução.

## Pré-requisitos

- Terraform instalado.
- Conta AWS e credenciais configuradas localmente para o AWS Provider, por
  exemplo, pelo AWS CLI ou por variáveis de ambiente.
- VPC padrão e sub-redes disponíveis em `us-east-1`.
- Permissões AWS para criar e consultar EC2, grupos de segurança, ELB e Auto
  Scaling.

## Como usar

No diretório do projeto, inicialize o Terraform:

```bash
terraform init
```

Valide a configuração e revise as alterações que serão aplicadas:

```bash
terraform validate
terraform plan
```

Crie os recursos:

```bash
terraform apply
```

Confirme a operação quando solicitado. Ao final, o Terraform mostra as saídas:

- `load_balancer_url`: endereço HTTP público do ALB.
- `public_ips`: IPs públicos das instâncias EC2 em execução encontradas.

Para remover os recursos criados por este projeto:

```bash
terraform destroy
```

## Custos e observações

Os recursos provisionados podem gerar cobranças na AWS, inclusive o ALB e as
instâncias EC2. Revise o plano antes de aplicar e execute `terraform destroy`
quando não precisar mais deles.

As instâncias recebem IP público, mas o grupo de segurança delas permite
entrada HTTP somente do ALB. O acesso web público deve ser feito pela URL do
balanceador.
