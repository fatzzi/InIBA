"""SCRUM-37: highlight_posts.position, the order of posts in a highlight (0 = cover)

Revision ID: 0005
Revises: 0004
Create Date: 2026-11-26 14:00:00
"""
from alembic import op
import sqlalchemy as sa


revision = '0005'
down_revision = '0004'
branch_labels = None
depends_on = None


def upgrade() -> None:
    with op.batch_alter_table('highlight_posts', schema=None) as batch_op:
        batch_op.add_column(sa.Column('position', sa.Integer(), nullable=False, server_default=sa.text('0')))


def downgrade() -> None:
    with op.batch_alter_table('highlight_posts', schema=None) as batch_op:
        batch_op.drop_column('position')
