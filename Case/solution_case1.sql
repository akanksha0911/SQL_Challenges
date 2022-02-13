CREATE SCHEMA hello_diner;
SHOW CREATE DATABASE hello_diner;
USE hello_diner;

CREATE TABLE sales
(
    customer_id VARCHAR(1),
    order_date  DATE,
    product_id  INTEGER
);

INSERT INTO sales
    (customer_id, order_date, product_id)
VALUES ('A', '2021-01-01', '1'),
       ('A', '2021-01-01', '2'),
       ('A', '2021-01-07', '2'),
       ('A', '2021-01-10', '3'),
       ('A', '2021-01-11', '3'),
       ('A', '2021-01-11', '3'),
       ('B', '2021-01-01', '2'),
       ('B', '2021-01-02', '2'),
       ('B', '2021-01-04', '1'),
       ('B', '2021-01-11', '1'),
       ('B', '2021-01-16', '3'),
       ('B', '2021-02-01', '3'),
       ('C', '2021-01-01', '3'),
       ('C', '2021-01-01', '3'),
       ('C', '2021-01-07', '3');


CREATE TABLE menu
(
    product_id   INTEGER,
    product_name VARCHAR(5),
    price        INTEGER
);

INSERT INTO menu
    (product_id, product_name, price)
VALUES ('1', 'sushi', '10'),
       ('2', 'curry', '15'),
       ('3', 'ramen', '12');


CREATE TABLE members
(
    customer_id VARCHAR(1),
    join_date   DATE
);

INSERT INTO members
    (customer_id, join_date)
VALUES ('A', '2021-01-07'),
       ('B', '2021-01-09');


# Case Study Questions
# 1. What is the total amount each customer spent at the restaurant?

select s.customer_id,
       SUM(m.price) AS amount_spent
from sales as s
         join menu as m
              on s.product_id = m.product_id
group by s.customer_id

# Answer:
#     Customer A spent $76.
#     Customer B spent $74.
#     Customer C spent $36.

# 2. How many days has each customer visited the restaurant?

select customer_id
     , count(distinct date(order_date)) as total_visting_days
from sales
group by customer_id;

# Answer:
#     Customer A visited 4 times.
#     Customer B visited 6 times.
#     Customer C visited 2 times.

# 3. What was the first item from the menu purchased by each customer?

with cte as (
    select s.customer_id,
           s.order_date,
           s.product_id,
           m.product_name,
           dense_rank() over (partition by s.customer_id order by s.order_date) as rnk
    from sales as s
             join menu as m
                  on s.product_id = m.product_id
)
select customer_id, product_name
from cte
where rnk = 1
group by customer_id, product_name;

# Answer:
#     Customer A’s first order are curry and sushi.
#     Customer B’s first order is curry.
#     Customer C’s first order is ramen.


# 4. What is the most purchased item on the menu and how many times was it purchased by all customers?

with cte as (
    SELECT product_id, total
    from (
             select count(*) as total,
                    product_id
             from sales
             group by product_id) t
    order by total desc
    limit 1
),
     temp as (
         select customer_id,
                sales.product_id,
                product_name,
                count(*) as per_person
         from sales
                  join menu
                       on sales.product_id = menu.product_id
         group by customer_id, product_id, product_name
         order by customer_id, product_id)
select customer_id, product_name, per_person, total
from temp
         join cte
              on temp.product_id = cte.product_id;

# Answer:
# A,ramen,3,8
# B,ramen,2,8
# C,ramen,3,8

# 5.Which item was the most popular for each customer?
with cte as (
    select s.customer_id,
           m.product_name,
           count(s.product_id)                                                         as tot,
           rank() over (partition by s.customer_id order by count(s.product_id) desc ) as rnk
    from sales as s
             join menu as m
                  on s.product_id = m.product_id
    group by customer_id, product_name)
select customer_id,
       product_name,
       tot
from cte
where rnk = 1;
# answer:
# A,ramen,3
# B,curry,2
# B,sushi,2
# B,ramen,2
# C,ramen,3


# 6.Which item was purchased first by the customer after they became a member?

with cte as (
    select distinct s.customer_id,
                    min(order_date) over (partition by s.customer_id) as fst
    from sales as s
             join members as m
                  on s.customer_id = m.customer_id
    where s.order_date >= m.join_date
    group by s.customer_id, order_date
),
     temp as (
         select s.customer_id,
                s.order_date,
                s.product_id,
                m.product_name
         from sales as s
                  join menu as m
                       on s.product_id = m.product_id
     )
select c.customer_id,
       t.product_name
from cte as c
         join temp as t
              on c.customer_id = t.customer_id and
                 c.fst = t.order_date;

# Answer: After Customer A became a member, his/her first order is curry, whereas it’s sushi for Customer B.

# 7. Which item was purchased just before the customer became a member?

with cte as (
    select s.customer_id,
           s.product_id,
           product_name,
           rank() over (partition by s.customer_id order by order_date) as rnk,
           order_date,
           join_date
    from sales as s
             join members m on s.customer_id = m.customer_id
             join menu as mu on s.product_id = mu.product_id
    where order_date < join_date)
select customer_id, product_id, product_name
from cte
where rnk = 1;

# Answer:
#  Customer A’s order before he/she became member is sushi and curry and Customer B’s order is sushi.

# 8. What is the total items and amount spent for each member before they became a member?
select s.customer_id,
       m.product_name,
       sum(m.price) as total
from sales as s
         join menu as m
              on s.product_id = m.product_id
         join members as m2
              on s.customer_id = m2.customer_id
where order_date < join_date
group by s.customer_id, m.product_name
order by s.customer_id

# answers:
# A,curry,15
# A,sushi,10
# B,curry,30
# B,sushi,10

# 9. If each $1 spent equates to 10 points and sushi has a 2x points multiplier
# how many points would each customer have?

select s.customer_id,
       sum((case
                when product_name = 'sushi' then price * 20
                else price * 10 end)) as points
from sales as s
         join menu as m
              on s.product_id = m.product_id
group by customer_id

# Answer:Total points for Customer A, B and C are 860, 940 and 360.

# 10. In the first week after a customer joins the program (including their join date)
# they earn 2x points on all items, not just sushi.
# how many points do customer A and B have at the end of January?

select s.customer_id,
  sum(case when (s.order_date-m2.join_date) between 0 and 6
      and order_date >= join_date
       then price*20
           when m.product_name = 'sushi' then price*20
       else price*10
       end) as total_point
from sales as s
join menu as m on s.product_id = m.product_id
join members as m2 on s.customer_id = m2.customer_id
where s.order_date <= '2021-01-31'
group by s.customer_id
order by s.customer_id;


# bonus question

SELECT s.customer_id,
       s.order_date,
       m.product_name,
       m.price,
CASE
 WHEN mm.join_date > s.order_date THEN 'N'
 WHEN mm.join_date <= s.order_date THEN 'Y'
 ELSE 'N'
 END AS member
FROM sales AS s
 left join menu AS m
 ON s.product_id = m.product_id
 left join members AS mm
 ON s.customer_id = mm.customer_id
order by customer_id, order_date, product_name;

WITH summary_cte AS
(
 SELECT s.customer_id, s.order_date, m.product_name, m.price,
  CASE
  WHEN mm.join_date > s.order_date THEN 'N'
  WHEN mm.join_date <= s.order_date THEN 'Y'
  ELSE 'N' END AS member
 FROM sales AS s
 LEFT JOIN menu AS m
  ON s.product_id = m.product_id
 LEFT JOIN members AS mm
  ON s.customer_id = mm.customer_id
)SELECT *,
        IF(member = 'N', NULL, RANK() OVER (PARTITION BY customer_id, member
            ORDER BY order_date)) AS ranking
FROM summary_cte;

######################################################################################
